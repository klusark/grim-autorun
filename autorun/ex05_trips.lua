-- The sets that the 100% run goes into only on a door trip (ar_door_trips, ar_full.lua): the story never takes Manny there, and a door of a set it sweeps
-- leads in (tools/cov100.py lists them as never entered). A door trip goes only to these, the first time one of their doors is swept past.
AR_TRIP_TO = AR_TRIP_TO or { }
AR_TRIP_TO["blimp bridge"] = TRUE
AR_TRIP_TO["bridge police side"] = TRUE
AR_TRIP_TO["cafe ledge"] = TRUE
AR_TRIP_TO["crane track"] = TRUE
AR_TRIP_TO["high roller pantry"] = TRUE
AR_TRIP_TO["mayan train station"] = TRUE
AR_TRIP_TO["ocean porthole"] = TRUE
AR_TRIP_TO["police interior"] = TRUE
AR_TRIP_TO["ramp"] = TRUE
