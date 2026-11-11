"""Names, revision and notes for the board this tools folder builds (Mainboard-USB rev A, 2026-10-31)."""
NS = '7d3e9a51-4c2b-4f18-9b6e-1a2c3d4e5f60'
PROJECT = 'moveOmeter_MBUSB'
LIB = 'MBUSB'
SHORT = 'Mainboard-USB'
TITLE = 'moveOmeter Mainboard-USB rev A (bench backboard for two SB1 rev B)'
REV = 'A'
DATE = '2026-10-31'
POWER_NETS = ('GND',)
ROOT_NOTES = (
    'moveOmeter Mainboard-USB rev A: passive desk backboard. A PC drives two SB1 rev B sensor boards through '
    'four CP2102 USB-TTL modules and two MCP2221A I2C breakouts (generated 2026-10-31)',
    'USB-C 5 V in (5.1k CC) straight through to both FFC links; a reset is an unplug.',
    'J2 takes SB1-A (left board of the V seen from the room), J3 takes SB1-B. Same 20-wire pinout as SB1.',
    'Everything marked VERIFY in field "Note" or in the plan doc must be checked before ordering.',
)
