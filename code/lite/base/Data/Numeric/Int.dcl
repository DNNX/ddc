module Int 
exports {

boxInt  ::
    [r : %].
    Int# -(Alloc r | Use r)>
    Int r;

unboxInt ::
    [r : %].
    Int r -(Read r | $0)>
    Int#;

addInt ::
    [r1 r2 r3 : %].
    Int r1 -(!0 | Use r3)>
    Int r2 -(Read r1 + Read r2 + Alloc r3 | Use r1 + Use r3)>
    Int r3;

subInt ::
    [r1 r2 r3 : %].
    Int r1 -(!0 | Use r3)>
    Int r2 -(Read r1 + Read r2 + Alloc r3 | Use r1 + Use r3)>
    Int r3;

mulInt ::
    [r1 r2 r3 : %].
    Int r1 -(!0 | Use r3)>
    Int r2 -(Read r1 + Read r2 + Alloc r3 | Use r1 + Use r3)>
    Int r3;

}
with letrec


-- | Box an integer.
boxInt  [r : %] 
        (i : Int#) { Alloc r | Use r } 
        : Int r
 = I# [r] i


-- | Unbox an integer.
unboxInt [r : %]
        (x : Int r) { Read r | $0 } 
        : Int#
 = case x of 
    I# i  -> i


-- | Add two integers.
addInt [r1 r2 r3 : %] 
        (x : Int r1) { !0 | Use r3 } 
        (y : Int r2) { Read r1 + Read r2 + Alloc r3 | Use r1 + Use r3 }
        : Int r3
 =  case x of { I# i1 
 -> case y of { I# i2 
 -> I# [r3] (add# [Int#] i1 i2) } }


-- | Subtract the second integer from the first.
subInt [r1 r2 r3 : %] 
        (x : Int r1) { !0 | Use r3 } 
        (y : Int r2) { Read r1 + Read r2 + Alloc r3 | Use r1 + Use r3 }
        : Int r3
 =  case x of { I# i1 
 -> case y of { I# i2 
 -> I# [r3] (sub# [Int#] i1 i2) } }


-- | Multiply two integers.
mulInt [r1 r2 r3 : %] 
        (x : Int r1) { !0 | Use r3 } 
        (y : Int r2) { Read r1 + Read r2 + Alloc r3 | Use r1 + Use r3 }
        : Int r3
 =  case x of { I# i1 
 -> case y of { I# i2 
 -> I# [r3] (mul# [Int#] i1 i2) } }



