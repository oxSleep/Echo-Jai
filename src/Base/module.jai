#load "math.jai";

thousand  :: inline (n: $T) -> T { return n *  cast(T) 1000;       }
million   :: inline (n: $T) -> T { return n *  cast(T) 1000000;    }
billion   :: inline (n: $T) -> T { return n *  cast(T) 1000000000; }
kilobytes :: inline (n: $T) -> T { return n << 10; }
megabytes :: inline (n: $T) -> T { return n << 20; }
gigabytes :: inline (n: $T) -> u64 { return cast(u64) n << 30; }
terabytes :: inline (n: $T) -> u64 { return cast(u64) n << 40; }

Align :: inline (n: $T, $$ align: s64) -> T {
    return (n + align-1) & ~(align-1);
}

check_nil :: inline (node: *$T, nil: *T = null) -> bool
{
    return node == null || node == nil;
}

set_nil :: inline (slot: **$T, nil: *T = null)
{
    <<slot = nil;
}


// Doubly-linked list helpers using the conventional next/prev field names.

dll_insert :: inline (first: **$T, last: **T, position: *T, node: *T, nil: *T = null)
{
    if check_nil(<<first, nil)
    {
        <<first = node;
        <<last  = node;
        node.next = nil;
        node.prev = nil;
    }
    else if check_nil(position, nil)
    {
        node.next = <<first;
        (<<first).prev = node;
        <<first = node;
        node.prev = nil;
    }
    else if position == <<last
    {
        (<<last).next = node;
        node.prev = <<last;
        <<last = node;
        node.next = nil;
    }
    else
    {
        if !check_nil(position.next, nil) position.next.prev = node;
        node.next = position.next;
        position.next = node;
        node.prev = position;
    }
}

dll_push_back :: inline (first: **$T, last: **T, node: *T, nil: *T = null)
{
    dll_insert(first, last, <<last, node, nil);
}

dll_push_front :: inline (first: **$T, last: **T, node: *T, nil: *T = null)
{
    dll_insert(first, last, nil, node, nil);
}

dll_remove :: inline (first: **$T, last: **T, node: *T, nil: *T = null)
{
    if node == <<first then <<first = node.next;
    if node == <<last  then <<last  = node.prev;
    if !check_nil(node.prev, nil) then node.prev.next = node.next;
    if !check_nil(node.next, nil) then node.next.prev = node.prev;
}


// Singly-linked queue helpers using the conventional next field name.

sll_queue_push :: inline (first: **$T, last: **T, node: *T, nil: *T = null)
{
    if check_nil(<<first, nil)
    {
        <<first = node;
        <<last  = node;
        node.next = nil;
    }
    else
    {
        (<<last).next = node;
        <<last = node;
        node.next = nil;
    }
}

sll_queue_push_front :: inline (first: **$T, last: **T, node: *T, nil: *T = null)
{
    if check_nil(<<first, nil)
    {
        <<first = node;
        <<last  = node;
        node.next = nil;
    }
    else
    {
        node.next = <<first;
        <<first = node;
    }
}

sll_queue_pop :: inline (first: **$T, last: **T, nil: *T = null)
{
    if <<first == <<last
    {
        set_nil(first, nil);
        set_nil(last, nil);
    }
    else
    {
        <<first = (<<first).next;
    }
}


// Singly-linked stack helpers using the conventional next field name.

sll_stack_push :: inline (first: **$T, node: *T)
{
    node.next = <<first;
    <<first = node;
}

sll_stack_pop :: inline (first: **$T)
{
    <<first = (<<first).next;
}


// Alternate singly-linked stack helpers when the link field is named 'prev'.

sll_stack_push_prev :: inline (first: **$T, node: *T)
{
    node.prev = <<first;
    <<first = node;
}

sll_stack_pop_prev :: inline (first: **$T)
{
    <<first = (<<first).prev;
}
