#module_parameters (ARENA_FREE_LIST := true);

alloc :: (reserve_size := ARENA_DEFAULT_RESERVE_SIZE, commit_size := ARENA_DEFAULT_COMMIT_SIZE, flags := ARENA_DEFAULT_FLAGS) -> *Arena
{
    reserve_size;
    commit_size;

    PAGE_SIZE :: 4096;  // Think about using bigger pages here.
    reserve_size = Align(reserve_size, PAGE_SIZE);
    commit_size  = Align(commit_size,  PAGE_SIZE);


    base := reserve(reserve_size);
    commit(base, commit_size);

    assert(base != null, "Arena creation failed to allocate.\n");

    arena := cast(*Arena) base;

    arena.prev     = null;
    arena.current  = arena;
    arena.flags    = flags;
    arena.cmt_size = commit_size;
    arena.res_size = reserve_size;
    arena.base_pos = 0;
    arena.pos      = ARENA_HEADER_SIZE;
    arena.res      = reserve_size;
    arena.cmt      = commit_size;

    return arena;
}

release :: (arena: *Arena)
{
    #if ARENA_FREE_LIST {
        free_list := arena.free_last;
    }

    n := arena.current;
    while n != null {
        prev := n.prev;
        release(n, n.res);
        n = prev;
    }

    #if ARENA_FREE_LIST {
        n = free_list;
        while n != null {
            prev := n.prev;
            release(n, n.res);
            n = prev;
        }
    }
}


push :: (arena: *Arena, size: s64, align: s64) -> *void
{
    current  := arena.current;
    pos_pre := Align(current.pos, align);
    pos_pst := pos_pre + size;

    // chain if needed
    if current.res < pos_pst && !(arena.flags & .NoChain)
    {
        new_block : *Arena;
        #if ARENA_FREE_LIST
        {
            prev_block: *Arena;
            new_block = arena.free_last;
            while new_block != null
            {
                if new_block.res >= Align(new_block.pos, align) + size
                {
                    if prev_block prev_block.prev = new_block.prev;
                    else arena.free_last = new_block.prev;
                    arena.free_size -= new_block.res_size;
                    break;
                }
                prev_block = new_block;
                new_block = new_block.prev;
            }
        }
        if new_block == null
        {
            res_size := current.res_size;
            cmt_size := current.cmt_size;

            if size + ARENA_HEADER_SIZE > res_size
            {
                res_size = Align(size + ARENA_HEADER_SIZE, align);
                cmt_size = res_size;
            }

            new_block = alloc(res_size, cmt_size, current.flags);
        }

        new_block.base_pos = current.base_pos + current.res;

        // push front
        sll_stack_push_prev(*arena.current, new_block);

        current = new_block;
        pos_pre = Align(current.pos, align);
        pos_pst = pos_pre + size;
    }

    // commit if needed
    if current.cmt < pos_pst
    {
        cmt_pst_aligned := pos_pst + current.cmt_size - 1;
        cmt_pst_aligned -= cmt_pst_aligned % current.cmt_size;

        cmt_pst_clamped := Min(cmt_pst_aligned, current.res);
        cmt_size        := cmt_pst_clamped - current.cmt;

        cmt_ptr := cast(*u8) current + current.cmt;

        commit(cmt_ptr, cmt_size);

        current.cmt = cmt_pst_clamped;
    }

    result: *void = null;

    if current.cmt >= pos_pst
    {
        result = cast(*u8) current + pos_pre;
        current.pos = pos_pst;
    }

    assert(result != null);

    return result;
}

pos :: (arena: *Arena) -> s64
{
    current := arena.current;
    return current.base_pos + current.pos;
}

pop_to :: (arena: *Arena, pos: s64)
{
    clamped := Max(ARENA_HEADER_SIZE, pos);
    current := arena.current;

    #if ARENA_FREE_LIST
    {
        prev: *Arena;
        while current.base_pos >= clamped
        {
            prev = current.prev;
            current.pos = ARENA_HEADER_SIZE;
            arena.free_size += current.res_size;

            sll_stack_push_prev(*arena.free_last, current);

            current = prev;
        }
    }
    else
    {
        prev: *Arena;
        while current.base_pos >= clamped
        {
            prev = current.prev;
            release(current, current.res);
            current = prev;
        }
    }

    arena.current = current;

    new_pos := clamped - current.base_pos;
    assert(new_pos <= current.pos);
    current.pos = new_pos;
}

pop :: (arena: *Arena, amount: s64)
{
    old := pos(arena);
    new := ifx amount < old then old - amount else old;
    pop_to(arena, new);
}

clear :: (arena: *Arena)
{
    pop_to(arena, 0);
}


PushArray :: inline (arena: *Arena, $T: Type, count: s64, align: s64 = DEFAULT_ALIGNMENT, $zero := true) -> *T
{
    size := size_of(T) * count;
    result := cast(*T) push(arena, cast(s64) size, cast(s64) align);
    #if zero {
        memset(result, 0, size_of(T) * count);
    }
    return result;
}

arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void
{
    arena := cast(*Arena) allocator_data;

    if #complete mode ==
    {
        case .ALLOCATE;
            assert(arena != null);
            if requested_size <= 0 return null;
            return push(arena, requested_size, DEFAULT_ALIGNMENT);

        case .RESIZE;
            assert(arena != null);
            if requested_size <= 0 return null;
            if old_memory == null return push(arena, requested_size, DEFAULT_ALIGNMENT);
            if requested_size <= old_size return old_memory;

            result := push(arena, requested_size, DEFAULT_ALIGNMENT);
            size_to_copy := Min(old_size, requested_size);
            if result && size_to_copy > 0
            {
                memcpy(result, old_memory, size_to_copy);
            }
            return result;

        case .FREE;
            return null;

        case .STARTUP; #through;
        case .SHUTDOWN;
            return null;

        case .THREAD_START; #through;
        case .THREAD_STOP;
            assert(false, "Multithreaded access is not supported by arena_allocator_proc.\n");
            return null;

        case .CREATE_HEAP; #through;
        case .DESTROY_HEAP;
            assert(false, "Create/Destroy heap are not supported by arena_allocator_proc.\n");
            return null;

        case .IS_THIS_YOURS;
            if arena == null || old_memory == null return null;

            memory := cast(*u8) old_memory;
            block := arena.current;
            while block != null
            {
                start := cast(*u8) block + ARENA_HEADER_SIZE;
                end   := cast(*u8) block + block.pos;
                if memory >= start && memory < end return cast(*void) 1;
                block = block.prev;
            }

            return null;

        case .CAPS;
            if old_memory
            {
                <<cast(*string) old_memory = CAPS_VERSION_STRING;
            }
            return cast(*void) (Allocator_Caps.HINT_I_AM_A_FAST_BUMP_ALLOCATOR|.IS_THIS_YOURS);
    }
}

get_allocator :: (arena: *Arena) -> Allocator
{
    return .{ arena_allocator_proc, arena };
}

Arena :: struct
{
    prev:    *Arena;
    current: *Arena;
    flags: Flags;
    cmt_size: s64;
    res_size: s64;
    base_pos: s64;
    pos: s64;
    cmt: s64;
    res: s64;
    #if ARENA_FREE_LIST
    {
        free_size: s64;
        free_last: *Arena = null;
    }
}


#scope_module

ARENA_DEFAULT_RESERVE_SIZE :: #run megabytes(32);
ARENA_DEFAULT_COMMIT_SIZE  :: #run kilobytes(64);
ARENA_HEADER_SIZE :: 128;
ARENA_DEFAULT_FLAGS :Flags: 1;
DEFAULT_ALIGNMENT :: 16;
CAPS_VERSION_STRING :: "Echo-Jai Arena";

Flags :: enum_flags u8
{
    NoChain :: 1;
}


#if OS == .WINDOWS
{
    #import "Windows";
    reserve :: (size: s64) -> *void
    {
        result := VirtualAlloc(null, cast(u64)size, MEM_RESERVE, PAGE_READWRITE);
        return result;
    }
    commit :: (ptr: *void, size: s64) -> bool
    {
        result := false;
        if VirtualAlloc(ptr, cast(u64)size, MEM_COMMIT, PAGE_READWRITE) result = true;
        return result;
    }
    decommit :: (ptr: *void, size: s64)
    {
        VirtualFree(ptr, cast(u64)size, MEM_DECOMMIT);
    }
    release :: (ptr: *void, size: s64)
    {
        VirtualFree(ptr, 0, MEM_RELEASE);
    }
} else assert(false, "Platform not supported.");

#import "Base";
#import "Basic";
#import "System";
