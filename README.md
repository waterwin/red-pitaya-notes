[![DOI](https://zenodo.org/badge/28404370.svg)](https://zenodo.org/badge/latestdoi/28404370)

# Red Pitaya Notes

Notes on the Red Pitaya Open Source Instrument

http://pavel-demin.github.io/red-pitaya-notes/

Edit - PE3ES - F4VTQ - 09/01/2022
For the FT8 transceiver 125-14 and 122.88-16 I changed parts of the scripts, cron, cfg files to make it possible :
-to keep the files from both input channels (antenna's) separated
-to report per input channel with a different callsign into pskreporter for analysis
-to switch in a day/night sequence from high to low bands to accommodate the 'only' 8 parallel receivers of the STEMlab 125-14 compared to the 16 in the SDRlab 122.88-16
