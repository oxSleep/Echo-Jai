// If no arena is provided, create a new one and store it in the array allocator.
// You can recover the arena later by casting allocator.data to *Arena.
arena_array_init :: (array: *[..]$T, arena: *Arena = null)
{
    if arena == null arena = arena_make();
    array.allocator = Allocator.{arena_allocator_proc, arena};
} 

arena_array_rewind :: (array: *[..] $T)
{
    assert(array.allocator.proc == arena_allocator_proc, "arena_array_rewind expects an arena-backed array.");

    arena := cast(*Arena) array.allocator.data;
    assert(arena != null, "arena_array_rewind requires allocator.data to contain an arena.");

    arena_pop_to(arena);
    array_reset(array);
}

Arena :: struct
{
    pos: s64;
    cmt: s64;
    res: s64;
    commit_granularity: s64;
}

arena_make :: (reserve_size := ARENA_DEFAULT_RESERVE_SIZE, commit_granularity := ARENA_DEFAULT_COMMIT_GRANULARITY) -> *Arena
{
    reserve_size       = Align(reserve_size,       PAGE_SIZE);
    commit_granularity = Align(commit_granularity, PAGE_SIZE);

    assert(commit_granularity > 0, "Arena commit granularity must be positive.");
    assert((commit_granularity & (commit_granularity - 1)) == 0, "Arena commit granularity must be a power of two.");

    base  := cast(*u8)reserve(reserve_size);
    arena := cast(*Arena)base;

    initial_commit := Align(arena_data_begin_offset(), PAGE_SIZE);
    commit(base, initial_commit);

    arena.pos = arena_data_begin_offset();
    arena.res = reserve_size;
    arena.cmt = initial_commit;
    arena.commit_granularity = commit_granularity;

    return arena;
}

arena_release :: (arena: *Arena) { release(arena_base(arena)); }

arena_push :: (arena: *Arena, nbytes: s64, alignment := 8) -> *void
{
    assert(arena != null);
    assert(nbytes >= 0);
    assert(alignment > 0);
    assert((alignment & (alignment - 1)) == 0, "Arena alignment must be a power of two.");

    position_pre  := Align(arena.pos, alignment);
    position_post := nbytes + position_pre;

    if position_post > arena.res return null;

    if arena.cmt < position_post
    {
        new_committed := Align(position_post, arena.commit_granularity);
        if new_committed > arena.res new_committed = arena.res;
        if !commit(arena_base(arena) + arena.cmt, new_committed - arena.cmt) return null;
        arena.cmt = new_committed;
    }

    arena.pos = position_post;
    return arena_base(arena) + position_pre;
}

arena_mark   :: (arena: *Arena) -> s64 { return arena.pos - arena_data_begin_offset(); }
arena_pop_to :: (arena: *Arena, position: s64 = 0)
{
    target := arena_data_begin_offset() + position;
    assert(target <= arena.pos, "Failed to rewind the arena from % to %", arena.pos, target);
    arena.pos = target;
}

arena_push_array :: inline (arena: *Arena, $T: Type, count: s64 = 1, align: s64 = 8, $zero := true) -> *T
{
    size := size_of(T) * count;
    result := cast(*T) arena_push(arena, cast(s64) size, cast(s64) align);
    #if zero {
        memset(result, 0, size_of(T) * count);
    }
    return result;
}

arena_allocator :: Allocator.{arena_allocator_proc, null};

arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void 
{
    if default_arena_proc == null default_arena_proc = arena_make();

    arena := ifx allocator_data then cast(*Arena)allocator_data else default_arena_proc;

    if #complete mode ==
    {
        case .ALLOCATE;
            if requested_size <= 0 return null;
            result := arena_push(arena, requested_size, 8);
            return result;

        case .RESIZE;
            if requested_size <= 0 return null;
            assert(old_size >= 0, "Old size must be non-negative.");

            // Basic.array_reserve routes first allocation through RESIZE, so treat a null
            // old pointer as a plain allocate rather than as an error.
            if old_memory == null return arena_push(arena, requested_size, 8);

            // Shrinking keeps the same pointer and does not reclaim bytes; arena space is
            // only recovered by rewinding the top of the arena.
            if requested_size <= old_size return old_memory;

            assert(old_memory >= arena_base_after_header(arena) && old_memory < arena_base(arena) + arena.pos, "Tried to resize memory not owned by this arena.");

            memory := cast(*u8) old_memory;
            base := arena_base(arena);

            start := memory - base;
            old_end := start + old_size;
            new_end := start + requested_size;

            // Only the most recent allocation may extend in place. Growing anything older
            // would move arena.pos through newer allocations and corrupt arena order.
            if old_end == arena.pos
            {
                if new_end > arena.res return null;
                if arena.cmt < new_end
                {
                    new_committed := Align(new_end, arena.commit_granularity);
                    if new_committed > arena.res new_committed = arena.res;
                    if !commit(arena_base(arena) + arena.cmt, new_committed - arena.cmt) return null;
                    arena.cmt = new_committed;
                }
                if arena.cmt >= new_end
                {
                    arena.pos = new_end;
                    return old_memory;
                }
                return null;
            }
            // A newer allocation already sits above this one, so preserve arena order by
            // appending a fresh block and copying the live prefix into it.
            result := arena_push(arena, requested_size, 8);
            size_to_copy := ifx old_size < requested_size then old_size else requested_size;
            if result && size_to_copy  memcpy(result, old_memory, size_to_copy);
            return result;

        case .CREATE_HEAP;
            return arena_make();

        case .DESTROY_HEAP;
            release(arena);
            return null;

        case .CAPS;
            if old_memory {<< cast(*string)old_memory = CAPS_VERSION_STRING;};
            return cast(*void)(Allocator_Caps.HINT_I_AM_A_FAST_BUMP_ALLOCATOR|.IS_THIS_YOURS|.CREATE_HEAP);

        case .IS_THIS_YOURS;
            if old_memory == null return null;
            result := (old_memory >= arena_base_after_header(arena)) && (old_memory < arena_base(arena) + arena.pos);
            return cast(*void) cast(s64)result;

        case .STARTUP;      #through;
        case .SHUTDOWN;     #through;
        case .THREAD_START; #through;
        case .THREAD_STOP;  #through;
        case .FREE; return null;
    }
}

#scope_module

default_arena_proc: *Arena;

arena_base :: (arena: *Arena) -> *u8 #expand { return cast(*u8)arena; }
arena_data_begin_offset :: () -> s64 #expand { return Align(size_of(Arena), 8); }
arena_base_after_header :: (arena: *Arena) -> *u8 #expand { return arena_base(arena) + arena_data_begin_offset(); }

Align :: inline (n: $T, $$ PAGE_SIZE: s64) -> T { return (n + PAGE_SIZE-1) & ~(PAGE_SIZE-1); }

ARENA_DEFAULT_RESERVE_SIZE       :: #run megabytes(32);
ARENA_DEFAULT_COMMIT_GRANULARITY :: #run kilobytes(64);
CAPS_VERSION_STRING              :: "Arena";

#if OS == .WINDOWS
{
    #import "Windows";
    PAGE_SIZE :: 4096;
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
    release :: (ptr: *void) { VirtualFree(ptr, 0, MEM_RELEASE); }
}

#import "Base";
#import "Basic";
#import "System";
