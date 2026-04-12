thousand  :: inline (n: $T) -> T { return n *  cast(T) 1000;       }
million   :: inline (n: $T) -> T { return n *  cast(T) 1000000;    }
billion   :: inline (n: $T) -> T { return n *  cast(T) 1000000000; }
kilobytes :: inline (n: $T) -> T { return n << 10; }
megabytes :: inline (n: $T) -> T { return n << 20; }
gigabytes :: inline (n: $T) -> u64 { return cast(u64) n << 30; }
terabytes :: inline (n: $T) -> u64 { return cast(u64) n << 40; }

f32 :: float32;

#load "math.jai";

