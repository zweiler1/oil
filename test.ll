define i32 @fib(i32 %n) { ; Some comment
entry:
  %n_lt_2 = icmp slt i32 %n, 2
  br i1 %n_lt_2, label %base, label %recurse

base:
  ret i32 %n

recurse:
  %n1 = sub i32 %n, 1
  %a  = call i32 @fib(i32 %n1)
  %n2 = sub i32 %n, 2
  %b  = call i32 @fib(i32 %n2)
  %r  = add i32 %a, %b
  ret i32 %r
}

define i32 @main() {
entry:
  %r = call i32 @fib(i32 6)
  ret i32 %r
}
