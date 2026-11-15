-- Spots of ar_blam_spots.lua where the word is typed this many frames after the game pushes its costume (ar_tricks.lua). There is no quiet frame before the push
-- (it comes in the frame its cutscene starts, with an object in front of Manny or an item in his hand), and the game pushes the same costume a second time
-- within 3 s: the word pops that one (the rope to the ledge 416 -> 192 frames, the bondo 420 -> 192)
AR_BLAM_AFTER = AR_BLAM_AFTER or { }
AR_BLAM_AFTER["ch06_year_end|verb:use /letx009/rope to ledge|1"] = 10
AR_BLAM_AFTER["ch06_year_end|cut:Glottis' Shop|3"] = 10
