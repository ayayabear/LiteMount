--[[----------------------------------------------------------------------------

  LiteMount/SpellInfo.lua

  Constants for mount spell information.

----------------------------------------------------------------------------]]--

-- Bits 1 through 16 match Blizzard's flags in GetCompanionInfo()
LM_FLAG_BIT_WALK = 1
LM_FLAG_BIT_FLY = 2
LM_FLAG_BIT_FLOAT = 4
LM_FLAG_BIT_SWIM = 8
LM_FLAG_BIT_JUMP = 16
LM_FLAG_BIT_SLOWWALK = 32
LM_FLAG_BIT_MOVING = 64
LM_FLAG_BIT_AQ = 128
LM_FLAG_BIT_VASHJIR = 256

LM_SPELL_TRAVEL_FORM = 783
LM_SPELL_GHOST_WOLF = 2645
LM_SPELL_AQUATIC_FORM = 1066
LM_SPELL_FLIGHT_FORM = 33943
LM_SPELL_RIDING_TURTLE = 30174
LM_SPELL_SWIFT_FLIGHT_FORM = 40120
LM_SPELL_SEA_TURTLE = 64731
LM_SPELL_ABYSSAL_SEAHORSE = 75207
LM_SPELL_SUBDUED_SEAHORSE = 98718
LM_SPELL_RUNNING_WILD = 87840
LM_SPELL_BLUE_QIRAJI_TANK = 25953
LM_SPELL_GREEN_QIRAJI_TANK = 26054
LM_SPELL_RED_QIRAJI_TANK = 26055
LM_SPELL_YELLOW_QIRAJI_TANK = 26056
LM_SPELL_BRONZE_DRAKE = 59569

LM_ITEM_DRAGONWRATH_TARECGOSAS_REST = 71086

-- Racial and Class spells don't appear in the companion index
LM_RACIAL_MOUNT_SPELLS = {
    LM_SPELL_RUNNING_WILD,
}

LM_CLASS_MOUNT_SPELLS = {
    LM_SPELL_AQUATIC_FORM,
    LM_SPELL_FLIGHT_FORM,
    LM_SPELL_GHOST_WOLF,
    LM_SPELL_SWIFT_FLIGHT_FORM,
    LM_SPELL_TRAVEL_FORM,
}

LM_ITEM_MOUNT_ITEMS = {
    LM_ITEM_DRAGONWRATH_TARECGOSAS_REST
}
    
LM_FlagOverrideTable = {
    [LM_SPELL_AQUATIC_FORM]       = bit.bor(LM_FLAG_BIT_FLOAT,
                                            LM_FLAG_BIT_SWIM),
    [LM_SPELL_RIDING_TURTLE]      = bit.bor(LM_FLAG_BIT_FLOAT,
                                            LM_FLAG_BIT_SWIM,
                                            LM_FLAG_BIT_SLOWWALK),
    [LM_SPELL_SEA_TURTLE]         = bit.bor(LM_FLAG_BIT_FLOAT,
                                            LM_FLAG_BIT_SWIM,
                                            LM_FLAG_BIT_SLOWWALK),
    [LM_SPELL_FLIGHT_FORM]        = bit.bor(LM_FLAG_BIT_FLY),
    [LM_SPELL_SWIFT_FLIGHT_FORM]  = bit.bor(LM_FLAG_BIT_FLY),
    [LM_SPELL_RUNNING_WILD]       = bit.bor(LM_FLAG_BIT_WALK),
    [LM_SPELL_GHOST_WOLF]         = bit.bor(LM_FLAG_BIT_SLOWWALK),
    [LM_SPELL_TRAVEL_FORM]        = bit.bor(LM_FLAG_BIT_SLOWWALK),
    [LM_SPELL_BLUE_QIRAJI_TANK]   = bit.bor(LM_FLAG_BIT_AQ),
    [LM_SPELL_GREEN_QIRAJI_TANK]  = bit.bor(LM_FLAG_BIT_AQ),
    [LM_SPELL_RED_QIRAJI_TANK]    = bit.bor(LM_FLAG_BIT_AQ),
    [LM_SPELL_YELLOW_QIRAJI_TANK] = bit.bor(LM_FLAG_BIT_AQ),
    [LM_SPELL_ABYSSAL_SEAHORSE]   = bit.bor(LM_FLAG_BIT_VASHJIR),
    [LM_SPELL_SUBDUED_SEAHORSE]   = bit.bor(LM_FLAG_BIT_FLOAT,
                                            LM_FLAG_BIT_SWIM,
                                            LM_FLAG_BIT_VASHJIR),
}
