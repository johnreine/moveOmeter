"""Names, revision and notes for the board this tools folder builds (SB1 rev B, 2026-10-31)."""
NS = '2c7e1d94-5a3b-4f60-8e2d-0b9a7c41d5e3'      # same uuid namespace as rev A
PROJECT = 'moveOmeter_SB1'
LIB = 'SB1'
SHORT = 'Sensor board SB1'
TITLE = 'moveOmeter sensor board SB1 rev B'
REV = 'B'
DATE = '2026-10-31'
POWER_NETS = ('GND', '+3V3')
ROOT_NOTES = (
    'moveOmeter sensor board SB1 rev B: LD6004 + LD2450, two I2S mics, ID EEPROM, light sensor; '
    '20-way FFC to the mainboard (generated 2026-10-31)',
    'Sub-sheets connect through global labels; power rails through power symbols.',
    'J7 is the only FFC connector (J3 removed 11/8): 51 mm Type A cable, eared, 20-way, 1.00 mm.',
    'Everything marked VERIFY in field "Note" or in the plan doc must be checked before ordering.',
)
