-- Act 4 chapter 4: Ozzie's tower: the plank to the short tower, up it, jump along the planks to the conch, the big switch
ar_load(425)
ar_a4_begin("26 tower")
-- (a huge set: the walk is planned on a coarse grid, A*)
AR_BIG_SET = TRUE
ar_do("pickUp", tow.plank)
ar_state("plank")
ar_do("use", tow.shorttower, tow.plank)
ar_state("plank placed")
ar_do("use", tow.shorttower)
ar_state("on the short tower")
ar_do("use", tow.plank2)
ar_state("on the planks")
ar_checkpoint(426)
