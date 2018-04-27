# Create xlslice
cell pavel-demin:user:port_slicer:1.0 slice_0 {
  DIN_WIDTH 8 DIN_FROM 0 DIN_TO 0
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_0 {
  NUM_PORTS 8
}

set prop_list {}
for {set i 0} {$i <= 7} {incr i} {
  lappend prop_list IN${i}_WIDTH 32
}
set_property -dict $prop_list [get_bd_cells concat_0]

for {set i 0} {$i <= 7} {incr i} {
  connect_bd_net [get_bd_pins concat_0/In$i] [get_bd_pins /adc_0/m_axis_tdata]
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_1 {
  NUM_PORTS 16
}

set prop_list {}
for {set i 0} {$i <= 15} {incr i} {
  lappend prop_list IN${i}_WIDTH 1
}
set_property -dict $prop_list [get_bd_cells concat_1]

for {set i 0} {$i <= 15} {incr i} {
  connect_bd_net [get_bd_pins concat_1/In$i] [get_bd_pins /adc_0/m_axis_tvalid]
}

# Create axis_switch
cell xilinx.com:ip:axis_switch:1.1 switch_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 2
  ROUTING_MODE 1
  NUM_SI 16
  NUM_MI 8
} {
  s_axis_tdata concat_0/dout
  s_axis_tvalid concat_1/dout
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

set prop_list {}
for {set i 0} {$i <= 7} {incr i} {
  for {set j 0} {$j <= 15} {incr j} {
    if {$i == $j / 2} continue
    lappend prop_list CONFIG.M[format %02d $i]_S[format %02d $j]_CONNECTIVITY 0
  }
}
set_property -dict $prop_list [get_bd_cells switch_0]

unset prop_list

for {set i 0} {$i <= 7} {incr i} {

  # Create xlslice
  cell pavel-demin:user:port_slicer:1.0 slice_[expr $i + 1] {
    DIN_WIDTH 256 DIN_FROM [expr 32 * $i + 31] DIN_TO [expr 32 * $i]
  }

  # Create axis_constant
  cell pavel-demin:user:axis_constant:1.0 phase_$i {
    AXIS_TDATA_WIDTH 32
  } {
    cfg_data slice_[expr $i + 1]/dout
    aclk /pll_0/clk_out1
  }

  # Create dds_compiler
  cell xilinx.com:ip:dds_compiler:6.0 dds_$i {
    DDS_CLOCK_RATE 125
    SPURIOUS_FREE_DYNAMIC_RANGE 138
    FREQUENCY_RESOLUTION 0.2
    PHASE_INCREMENT Streaming
    HAS_PHASE_OUT false
    PHASE_WIDTH 30
    OUTPUT_WIDTH 24
    DSP48_USE Minimal
    NEGATIVE_SINE true
  } {
    S_AXIS_PHASE phase_$i/M_AXIS
    aclk /pll_0/clk_out1
  }

}

# Create axis_lfsr
cell pavel-demin:user:axis_lfsr:1.0 lfsr_0 {} {
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

for {set i 0} {$i <= 15} {incr i} {

  # Create xlslice
  cell pavel-demin:user:port_slicer:1.0 adc_slice_$i {
    DIN_WIDTH 128 DIN_FROM [expr 16 * ($i / 2) + 13] DIN_TO [expr 16 * ($i / 2)]
  } {
    din switch_0/m_axis_tdata
  }

  # Create xlslice
  cell pavel-demin:user:port_slicer:1.0 dds_slice_$i {
    DIN_WIDTH 48 DIN_FROM [expr 24 * ($i % 2) + 23] DIN_TO [expr 24 * ($i % 2)]
  } {
    din dds_[expr $i / 2]/m_axis_data_tdata
  }

  cell xilinx.com:ip:xbip_dsp48_macro:3.0 mult_$i {
    INSTRUCTION1 RNDSIMPLE(A*B+CARRYIN)
    A_WIDTH.VALUE_SRC USER
    B_WIDTH.VALUE_SRC USER
    OUTPUT_PROPERTIES User_Defined
    A_WIDTH 24
    B_WIDTH 14
    P_WIDTH 25
  } {
    A dds_slice_$i/dout
    B adc_slice_$i/dout
    CARRYIN lfsr_0/m_axis_tdata
    CLK /pll_0/clk_out1
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler:4.0 cic_$i {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Decimation
    NUMBER_OF_STAGES 6
    SAMPLE_RATE_CHANGES Fixed
    FIXED_OR_INITIAL_RATE 250
    INPUT_SAMPLE_FREQUENCY 125
    CLOCK_FREQUENCY 125
    INPUT_DATA_WIDTH 24
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 24
    USE_XTREME_DSP_SLICE false
    HAS_DOUT_TREADY true
    HAS_ARESETN true
  } {
    s_axis_data_tdata mult_$i/P
    s_axis_data_tvalid const_0/dout
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner:1.1 comb_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 3
  NUM_SI 16
} {
  S00_AXIS cic_0/M_AXIS_DATA
  S01_AXIS cic_1/M_AXIS_DATA
  S02_AXIS cic_2/M_AXIS_DATA
  S03_AXIS cic_3/M_AXIS_DATA
  S04_AXIS cic_4/M_AXIS_DATA
  S05_AXIS cic_5/M_AXIS_DATA
  S06_AXIS cic_6/M_AXIS_DATA
  S07_AXIS cic_7/M_AXIS_DATA
  S08_AXIS cic_8/M_AXIS_DATA
  S09_AXIS cic_9/M_AXIS_DATA
  S10_AXIS cic_10/M_AXIS_DATA
  S11_AXIS cic_11/M_AXIS_DATA
  S12_AXIS cic_12/M_AXIS_DATA
  S13_AXIS cic_13/M_AXIS_DATA
  S14_AXIS cic_14/M_AXIS_DATA
  S15_AXIS cic_15/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 48
  M_TDATA_NUM_BYTES 3
} {
  S_AXIS comb_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create cic_compiler
cell xilinx.com:ip:cic_compiler:4.0 cic_16 {
  INPUT_DATA_WIDTH.VALUE_SRC USER
  FILTER_TYPE Decimation
  NUMBER_OF_STAGES 6
  SAMPLE_RATE_CHANGES Fixed
  FIXED_OR_INITIAL_RATE 250
  INPUT_SAMPLE_FREQUENCY 0.5
  CLOCK_FREQUENCY 125
  NUMBER_OF_CHANNELS 16
  INPUT_DATA_WIDTH 24
  QUANTIZATION Truncation
  OUTPUT_DATA_WIDTH 32
  USE_XTREME_DSP_SLICE false
  HAS_DOUT_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA conv_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler:7.2 fir_0 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 32
  COEFFICIENTVECTOR {-4.5790375204e-09, 3.2302274968e-08, -7.2368822924e-08, -5.9907576134e-07, -1.7757370931e-06, -3.4857495204e-06, -4.9780393315e-06, -4.7958554438e-06, -1.1326751631e-06, 7.3322268537e-06, 2.0348792717e-05, 3.5289203898e-05, 4.7279332399e-05, 5.0731317975e-05, 4.2162017121e-05, 2.3373038503e-05, 3.3779037884e-06, -2.6685549279e-06, 2.1473560236e-05, 8.4735156400e-05, 1.7969301329e-04, 2.7712431298e-04, 3.2851400619e-04, 2.7886737182e-04, 8.8220639572e-05, -2.4453587859e-04, -6.6556709139e-04, -1.0682182834e-03, -1.3196985945e-03, -1.3101745198e-03, -1.0114878487e-03, -5.2373891320e-04, -8.4928656017e-05, -2.4801156554e-05, -6.5928559403e-04, -2.1432457789e-03, -4.3202019053e-03, -6.6204905240e-03, -8.0574171741e-03, -7.3516948026e-03, -3.1808267321e-03, 5.4894105914e-03, 1.9067670499e-02, 3.7085847996e-02, 5.8116235861e-02, 7.9903975351e-02, 9.9708725431e-02, 1.1479288969e-01, 1.2295004672e-01, 1.2295004672e-01, 1.1479288969e-01, 9.9708725431e-02, 7.9903975351e-02, 5.8116235861e-02, 3.7085847996e-02, 1.9067670499e-02, 5.4894105914e-03, -3.1808267321e-03, -7.3516948026e-03, -8.0574171741e-03, -6.6204905240e-03, -4.3202019053e-03, -2.1432457789e-03, -6.5928559403e-04, -2.4801156554e-05, -8.4928656017e-05, -5.2373891320e-04, -1.0114878487e-03, -1.3101745198e-03, -1.3196985945e-03, -1.0682182834e-03, -6.6556709139e-04, -2.4453587859e-04, 8.8220639572e-05, 2.7886737182e-04, 3.2851400619e-04, 2.7712431298e-04, 1.7969301329e-04, 8.4735156400e-05, 2.1473560236e-05, -2.6685549279e-06, 3.3779037884e-06, 2.3373038503e-05, 4.2162017121e-05, 5.0731317975e-05, 4.7279332399e-05, 3.5289203898e-05, 2.0348792717e-05, 7.3322268537e-06, -1.1326751631e-06, -4.7958554438e-06, -4.9780393315e-06, -3.4857495204e-06, -1.7757370931e-06, -5.9907576134e-07, -7.2368822924e-08, 3.2302274968e-08, -4.5790375204e-09}
  COEFFICIENT_WIDTH 32
  QUANTIZATION Maximize_Dynamic_Range
  BESTPRECISION true
  FILTER_TYPE Decimation
  RATE_CHANGE_TYPE Fixed_Fractional
  INTERPOLATION_RATE 3
  DECIMATION_RATE 4
  NUMBER_CHANNELS 16
  NUMBER_PATHS 1
  SAMPLE_FREQUENCY 0.002
  CLOCK_FREQUENCY 125
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 33
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA cic_16/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 subset_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 5
  M_TDATA_NUM_BYTES 4
  TDATA_REMAP {tdata[31:0]}
} {
  S_AXIS fir_0/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler:7.2 fir_1 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 32
  COEFFICIENTVECTOR {5.4927693378e-09, -5.4202981892e-09, -1.4291030349e-08, -1.4819388832e-08, -5.4238921654e-09, 8.8721173731e-09, 1.8834600847e-08, 1.6755375010e-08, 2.1172292899e-09, -1.6760029322e-08, -2.6949364939e-08, -1.9157019815e-08, 4.9842563544e-09, 3.1785594688e-08, 4.2512628698e-08, 2.5346322915e-08, -1.4864158612e-08, -5.6120054588e-08, -7.0300288544e-08, -4.0710708236e-08, 2.4137523187e-08, 9.0379845454e-08, 1.1519990839e-07, 7.2553127416e-08, -2.6430995802e-08, -1.3246173316e-07, -1.8101007055e-07, -1.2943146121e-07, 1.2132596032e-08, 1.7641492084e-07, 2.6889423242e-07, 2.1989756390e-07, 3.1262137530e-08, -2.1162832431e-07, -3.7570404832e-07, -3.5069623288e-07, -1.1809018762e-07, 2.2256683662e-07, 4.9239961486e-07, 5.2451507251e-07, 2.6262589341e-07, -1.8937148571e-07, -6.0296309301e-07, -7.3760423799e-07, -4.7645792790e-07, 8.9471704940e-08, 6.8413591778e-07, 9.7761380573e-07, 7.6532006810e-07, 9.9688847519e-08, -7.0635447387e-07, -1.2221571019e-06, -1.1258055371e-06, -3.9697700008e-07, 6.3605629324e-07, 1.4385193415e-06, 1.5424139888e-06, 8.1317198357e-07, -4.3952180617e-07, -1.5850687045e-06, -1.9857001621e-06, -1.3465380774e-06, 8.7899090312e-08, 1.6144747888e-06, 2.4119900657e-06, 1.9789185524e-06, 4.3688924213e-07, -1.4789187695e-06, -2.7653507925e-06, -2.6733134624e-06, -1.1362202117e-06, 1.1368881267e-06, 2.9820285655e-06, 3.3736601175e-06, 1.9896847311e-06, -5.6101094408e-07, -2.9974595993e-06, -4.0076220919e-06, -2.9520771091e-06, -2.5425135237e-07, 2.7552012589e-06, 4.4924995093e-06, 3.9532073793e-06, 1.2859768188e-06, -2.2172702934e-06, -4.7446001508e-06, -4.9018031489e-06, -2.4790609019e-06, 1.3741193424e-06, 4.6910201149e-06, 5.6935124282e-06, 3.7463377608e-06, -2.5296428502e-07, -4.2829651759e-06, -6.2231578239e-06, -4.9738509905e-06, -1.0775795383e-06, 3.5086404150e-06, 6.4001645513e-06, 6.0315378346e-06, 2.5079843838e-06, -2.4038615471e-06, -6.1659149978e-06, -6.7894892924e-06, -3.8952056156e-06, 1.0574962600e-06, 5.5100693667e-06, 7.1378483164e-06, 5.0766973622e-06, 3.8946439893e-07, -4.4840757323e-06, -7.0092532783e-06, -5.8916558036e-06, -1.7537739542e-06, 3.2080096312e-06, 6.4000207156e-06, 6.2071564161e-06, 2.8286982433e-06, -1.8686882323e-06, -5.3871008542e-06, -5.9469639160e-06, -3.4115750746e-06, 7.0663822277e-07, 4.1366351066e-06, 5.1187468566e-06, 3.3375680217e-06, 8.1805851018e-09, -2.9015856660e-06, -3.8362450862e-06, -2.5173497056e-06, -1.2552526211e-08, 2.0043517887e-06, 2.3299083932e-06, 9.7200461545e-07, -9.0651824871e-07, -1.8054610497e-06, -9.4380899514e-07, 1.1385111941e-06, 2.8635609964e-06, 2.6575746488e-06, 1.1414865751e-07, -3.5006637272e-06, -5.8288696469e-06, -4.8491200032e-06, -3.2906041854e-07, 5.6508988033e-06, 9.5915188355e-06, 8.5422611527e-06, 2.0700057444e-06, -7.0024523477e-06, -1.3739894809e-05, -1.3714353729e-05, -5.7407637575e-06, 6.8946497941e-06, 1.7663719597e-05, 2.0108642223e-05, 1.1587425720e-05, -4.6669655858e-06, -2.0586403935e-05, -2.7207439215e-05, -1.9622687565e-05, -2.5090725654e-07, 2.1626201185e-05, 3.4232896269e-05, 2.9562491245e-05, 8.2388128549e-06, -1.9886733483e-05, -4.0183503917e-05, -4.0788154317e-05, -1.9388649023e-05, 1.4569586603e-05, 4.3907647556e-05, 5.2342899279e-05, 3.3421306727e-05, -5.1010888274e-06, -4.4215319481e-05, -6.2974228244e-05, -4.9636536470e-05, -8.7457444366e-06, 4.0015245714e-05, 7.1219465651e-05, 6.6901977563e-05, 2.6743538751e-05, -3.0472446388e-05, -7.5539870235e-05, -8.3698304387e-05, -4.8141221334e-05, 1.5163310449e-05, 7.4489834365e-05, 9.8220829067e-05, 7.1645371251e-05, 5.7887846848e-06, -6.6909299486e-05, -1.0853826700e-04, -9.5467147501e-05, -3.1621153593e-05, 5.2116326434e-05, 1.1279603687e-04, 1.1743738664e-04, 6.0897891203e-05, -3.0081505458e-05, -1.0945434849e-04, -1.3519739401e-04, -9.1560459380e-05, 1.5466409584e-06, 9.7524522038e-05, 1.4644205367e-04, 1.2105866392e-04, 3.1924377970e-05, -7.6786247476e-05, -1.4920656639e-04, -1.4657185981e-04, -6.7991863195e-05, 4.7945848376e-05, 1.4216123424e-04, 1.6530316344e-04, 1.0369110180e-04, -1.2708708697e-05, -1.2488239264e-04, -1.7482713415e-04, -1.3569269695e-04, -2.6264947657e-05, 9.8053799565e-05, 1.7344825348e-04, 1.6064923837e-04, 6.5523915763e-05, -6.3575869656e-05, -1.6054535825e-04, -1.7562137571e-04, -1.0113363162e-04, 2.4528302197e-05, 1.3683229380e-04, 1.7852119733e-04, 1.2909336182e-04, 1.5015517354e-05, -1.0450592646e-04, -1.6853822209e-04, -1.4584668667e-04, -5.0339848297e-05, 6.7231585148e-05, 1.4648367665e-04, 1.4883301802e-04, 7.6585620458e-05, -2.9943151222e-05, -1.1500259363e-04, -1.3702962772e-04, -8.9376165110e-05, -1.5682848284e-06, 7.8583873520e-05, 1.1139372742e-04, 8.5491031133e-05, 2.1236659183e-05, -4.3363705894e-05, -7.5170987825e-05, -6.3557366481e-05, -2.3479268154e-05, 1.6664629540e-05, 3.3968637993e-05, 2.4643786366e-05, 4.0425573681e-06, -6.3027700078e-06, 4.4354026242e-06, 2.7309882632e-05, 3.9128416089e-05, 1.9684612977e-05, -3.0587562437e-05, -8.5317648482e-05, -1.0510140740e-04, -6.2767239550e-05, 3.4144873412e-05, 1.3947533045e-04, 1.8932665433e-04, 1.3893869047e-04, -4.9609560576e-06, -1.7748237220e-04, -2.8331860101e-04, -2.4798703336e-04, -6.5657083030e-05, 1.8550331877e-04, 3.7466824044e-04, 3.8521117726e-04, 1.8355215825e-04, -1.4940565128e-04, -4.4750327057e-04, -5.4084193243e-04, -3.5034260570e-04, 5.6279338840e-05, 4.8340013655e-04, 6.9986306075e-04, 5.6219139453e-04, 1.0384635845e-04, -4.6275378202e-04, -8.4233895649e-04, -8.0888945252e-04, -3.3625597641e-04, 3.6650451623e-04, 9.4424261010e-04, 1.0733176822e-03, 6.3984167547e-04, -1.7822014902e-04, -9.7889979638e-04, -1.3315182832e-03, -1.0057272795e-03, -1.1373125890e-04, 9.1888218947e-04, 1.5533325353e-03, 1.4162730226e-03, 5.1398795234e-04, -7.3834033767e-04, -1.7037035803e-03, -1.8446566013e-03, -1.0182094994e-03, 4.1559954137e-04, 1.7445849987e-03, 2.2551008826e-03, 1.6114499969e-03, 6.4119811479e-05, -1.6374180734e-03, -2.6038608020e-03, -2.2671366758e-03, -7.0616932645e-04, 1.3458922617e-03, 2.8407789701e-03, 2.9465720891e-03, 1.5041064510e-03, -8.3903429497e-04, -2.9115634683e-03, -3.5992614458e-03, -2.4379196578e-03, 9.4161752855e-05, 2.7603931385e-03, 4.1638294450e-03, 3.4727996327e-03, 9.0040044686e-04, -2.3327061874e-03, -4.5694644048e-03, -4.5585681984e-03, -2.1431407788e-03, 1.5777628076e-03, 4.7375192585e-03, 5.6295866287e-03, 3.6178099059e-03, -4.5068400431e-04, -4.5829732470e-03, -6.6051334388e-03, -5.2930002520e-03, -1.0870730238e-03, 4.0144293059e-03, 7.3891049751e-03, 7.1223519604e-03, 3.0691214050e-03, -2.9318141674e-03, -7.8684560934e-03, -9.0459318382e-03, -5.5295491205e-03, 1.2185797431e-03, 7.9075663836e-03, 1.0992229577e-02, 8.5151596016e-03, 1.2770643306e-03, -7.3334731244e-03, -1.2880394065e-02, -1.2111846714e-02, -4.7856300905e-03, 5.8987449335e-03, 1.4620793261e-02, 1.6503094048e-02, 9.7205045713e-03, -3.1864481673e-03, -1.6110831011e-02, -2.2119833176e-02, -1.6964703838e-02, -1.6719381896e-03, 1.7204689687e-02, 3.0098500304e-02, 2.8835433001e-02, 1.1042660009e-02, -1.7542727996e-02, -4.4215916528e-02, -5.3801469910e-02, -3.4881445897e-02, 1.4787677109e-02, 8.6066657891e-02, 1.6062575452e-01, 2.1694107327e-01, 2.3788238010e-01, 2.1694107327e-01, 1.6062575452e-01, 8.6066657891e-02, 1.4787677109e-02, -3.4881445897e-02, -5.3801469910e-02, -4.4215916528e-02, -1.7542727996e-02, 1.1042660009e-02, 2.8835433001e-02, 3.0098500304e-02, 1.7204689687e-02, -1.6719381896e-03, -1.6964703838e-02, -2.2119833176e-02, -1.6110831011e-02, -3.1864481673e-03, 9.7205045713e-03, 1.6503094048e-02, 1.4620793261e-02, 5.8987449335e-03, -4.7856300905e-03, -1.2111846714e-02, -1.2880394065e-02, -7.3334731244e-03, 1.2770643306e-03, 8.5151596016e-03, 1.0992229577e-02, 7.9075663836e-03, 1.2185797431e-03, -5.5295491205e-03, -9.0459318382e-03, -7.8684560934e-03, -2.9318141674e-03, 3.0691214050e-03, 7.1223519604e-03, 7.3891049751e-03, 4.0144293059e-03, -1.0870730238e-03, -5.2930002520e-03, -6.6051334388e-03, -4.5829732470e-03, -4.5068400431e-04, 3.6178099059e-03, 5.6295866287e-03, 4.7375192585e-03, 1.5777628076e-03, -2.1431407788e-03, -4.5585681984e-03, -4.5694644048e-03, -2.3327061874e-03, 9.0040044686e-04, 3.4727996327e-03, 4.1638294450e-03, 2.7603931385e-03, 9.4161752855e-05, -2.4379196578e-03, -3.5992614458e-03, -2.9115634683e-03, -8.3903429497e-04, 1.5041064510e-03, 2.9465720891e-03, 2.8407789701e-03, 1.3458922617e-03, -7.0616932645e-04, -2.2671366758e-03, -2.6038608020e-03, -1.6374180734e-03, 6.4119811479e-05, 1.6114499969e-03, 2.2551008826e-03, 1.7445849987e-03, 4.1559954137e-04, -1.0182094994e-03, -1.8446566013e-03, -1.7037035803e-03, -7.3834033767e-04, 5.1398795234e-04, 1.4162730226e-03, 1.5533325353e-03, 9.1888218947e-04, -1.1373125890e-04, -1.0057272795e-03, -1.3315182832e-03, -9.7889979638e-04, -1.7822014902e-04, 6.3984167547e-04, 1.0733176822e-03, 9.4424261010e-04, 3.6650451623e-04, -3.3625597641e-04, -8.0888945252e-04, -8.4233895649e-04, -4.6275378202e-04, 1.0384635845e-04, 5.6219139453e-04, 6.9986306075e-04, 4.8340013655e-04, 5.6279338840e-05, -3.5034260570e-04, -5.4084193243e-04, -4.4750327057e-04, -1.4940565128e-04, 1.8355215825e-04, 3.8521117726e-04, 3.7466824044e-04, 1.8550331877e-04, -6.5657083030e-05, -2.4798703336e-04, -2.8331860101e-04, -1.7748237220e-04, -4.9609560576e-06, 1.3893869047e-04, 1.8932665433e-04, 1.3947533045e-04, 3.4144873412e-05, -6.2767239550e-05, -1.0510140740e-04, -8.5317648482e-05, -3.0587562437e-05, 1.9684612977e-05, 3.9128416089e-05, 2.7309882632e-05, 4.4354026242e-06, -6.3027700078e-06, 4.0425573681e-06, 2.4643786366e-05, 3.3968637993e-05, 1.6664629540e-05, -2.3479268154e-05, -6.3557366481e-05, -7.5170987825e-05, -4.3363705894e-05, 2.1236659183e-05, 8.5491031133e-05, 1.1139372742e-04, 7.8583873520e-05, -1.5682848284e-06, -8.9376165110e-05, -1.3702962772e-04, -1.1500259363e-04, -2.9943151222e-05, 7.6585620458e-05, 1.4883301802e-04, 1.4648367665e-04, 6.7231585148e-05, -5.0339848297e-05, -1.4584668667e-04, -1.6853822209e-04, -1.0450592646e-04, 1.5015517354e-05, 1.2909336182e-04, 1.7852119733e-04, 1.3683229380e-04, 2.4528302197e-05, -1.0113363162e-04, -1.7562137571e-04, -1.6054535825e-04, -6.3575869656e-05, 6.5523915763e-05, 1.6064923837e-04, 1.7344825348e-04, 9.8053799565e-05, -2.6264947657e-05, -1.3569269695e-04, -1.7482713415e-04, -1.2488239264e-04, -1.2708708697e-05, 1.0369110180e-04, 1.6530316344e-04, 1.4216123424e-04, 4.7945848376e-05, -6.7991863195e-05, -1.4657185981e-04, -1.4920656639e-04, -7.6786247476e-05, 3.1924377970e-05, 1.2105866392e-04, 1.4644205367e-04, 9.7524522038e-05, 1.5466409584e-06, -9.1560459380e-05, -1.3519739401e-04, -1.0945434849e-04, -3.0081505458e-05, 6.0897891203e-05, 1.1743738664e-04, 1.1279603687e-04, 5.2116326434e-05, -3.1621153593e-05, -9.5467147501e-05, -1.0853826700e-04, -6.6909299486e-05, 5.7887846848e-06, 7.1645371251e-05, 9.8220829067e-05, 7.4489834365e-05, 1.5163310449e-05, -4.8141221334e-05, -8.3698304387e-05, -7.5539870235e-05, -3.0472446388e-05, 2.6743538751e-05, 6.6901977563e-05, 7.1219465651e-05, 4.0015245714e-05, -8.7457444366e-06, -4.9636536470e-05, -6.2974228244e-05, -4.4215319481e-05, -5.1010888274e-06, 3.3421306727e-05, 5.2342899279e-05, 4.3907647556e-05, 1.4569586603e-05, -1.9388649023e-05, -4.0788154317e-05, -4.0183503917e-05, -1.9886733483e-05, 8.2388128549e-06, 2.9562491245e-05, 3.4232896269e-05, 2.1626201185e-05, -2.5090725654e-07, -1.9622687565e-05, -2.7207439215e-05, -2.0586403935e-05, -4.6669655858e-06, 1.1587425720e-05, 2.0108642223e-05, 1.7663719597e-05, 6.8946497941e-06, -5.7407637575e-06, -1.3714353729e-05, -1.3739894809e-05, -7.0024523478e-06, 2.0700057444e-06, 8.5422611527e-06, 9.5915188355e-06, 5.6508988033e-06, -3.2906041854e-07, -4.8491200032e-06, -5.8288696469e-06, -3.5006637272e-06, 1.1414865751e-07, 2.6575746488e-06, 2.8635609964e-06, 1.1385111941e-06, -9.4380899514e-07, -1.8054610497e-06, -9.0651824871e-07, 9.7200461545e-07, 2.3299083932e-06, 2.0043517887e-06, -1.2552526212e-08, -2.5173497056e-06, -3.8362450862e-06, -2.9015856660e-06, 8.1805851015e-09, 3.3375680217e-06, 5.1187468566e-06, 4.1366351066e-06, 7.0663822277e-07, -3.4115750746e-06, -5.9469639160e-06, -5.3871008542e-06, -1.8686882323e-06, 2.8286982433e-06, 6.2071564161e-06, 6.4000207156e-06, 3.2080096312e-06, -1.7537739542e-06, -5.8916558036e-06, -7.0092532783e-06, -4.4840757323e-06, 3.8946439893e-07, 5.0766973622e-06, 7.1378483164e-06, 5.5100693667e-06, 1.0574962600e-06, -3.8952056156e-06, -6.7894892924e-06, -6.1659149978e-06, -2.4038615471e-06, 2.5079843838e-06, 6.0315378346e-06, 6.4001645513e-06, 3.5086404150e-06, -1.0775795383e-06, -4.9738509905e-06, -6.2231578239e-06, -4.2829651759e-06, -2.5296428502e-07, 3.7463377608e-06, 5.6935124282e-06, 4.6910201149e-06, 1.3741193424e-06, -2.4790609019e-06, -4.9018031489e-06, -4.7446001508e-06, -2.2172702934e-06, 1.2859768188e-06, 3.9532073793e-06, 4.4924995093e-06, 2.7552012589e-06, -2.5425135237e-07, -2.9520771091e-06, -4.0076220919e-06, -2.9974595993e-06, -5.6101094408e-07, 1.9896847311e-06, 3.3736601175e-06, 2.9820285655e-06, 1.1368881267e-06, -1.1362202117e-06, -2.6733134624e-06, -2.7653507925e-06, -1.4789187695e-06, 4.3688924213e-07, 1.9789185524e-06, 2.4119900657e-06, 1.6144747888e-06, 8.7899090312e-08, -1.3465380774e-06, -1.9857001621e-06, -1.5850687045e-06, -4.3952180617e-07, 8.1317198357e-07, 1.5424139888e-06, 1.4385193415e-06, 6.3605629324e-07, -3.9697700008e-07, -1.1258055371e-06, -1.2221571019e-06, -7.0635447387e-07, 9.9688847519e-08, 7.6532006810e-07, 9.7761380573e-07, 6.8413591778e-07, 8.9471704940e-08, -4.7645792790e-07, -7.3760423799e-07, -6.0296309301e-07, -1.8937148571e-07, 2.6262589341e-07, 5.2451507251e-07, 4.9239961486e-07, 2.2256683662e-07, -1.1809018762e-07, -3.5069623288e-07, -3.7570404832e-07, -2.1162832431e-07, 3.1262137530e-08, 2.1989756390e-07, 2.6889423242e-07, 1.7641492084e-07, 1.2132596032e-08, -1.2943146121e-07, -1.8101007055e-07, -1.3246173316e-07, -2.6430995802e-08, 7.2553127416e-08, 1.1519990839e-07, 9.0379845454e-08, 2.4137523187e-08, -4.0710708236e-08, -7.0300288544e-08, -5.6120054588e-08, -1.4864158612e-08, 2.5346322915e-08, 4.2512628698e-08, 3.1785594688e-08, 4.9842563544e-09, -1.9157019815e-08, -2.6949364939e-08, -1.6760029322e-08, 2.1172292899e-09, 1.6755375010e-08, 1.8834600847e-08, 8.8721173731e-09, -5.4238921654e-09, -1.4819388832e-08, -1.4291030349e-08, -5.4202981892e-09, 5.4927693378e-09}
  COEFFICIENT_WIDTH 32
  QUANTIZATION Maximize_Dynamic_Range
  BESTPRECISION true
  FILTER_TYPE Decimation
  DECIMATION_RATE 4
  NUMBER_CHANNELS 16
  NUMBER_PATHS 1
  SAMPLE_FREQUENCY 0.0015
  CLOCK_FREQUENCY 125
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 33
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA subset_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 subset_1 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 5
  M_TDATA_NUM_BYTES 4
  TDATA_REMAP {tdata[31:0]}
} {
  S_AXIS fir_1/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create floating_point
cell xilinx.com:ip:floating_point:7.1 fp_0 {
  OPERATION_TYPE Fixed_to_float
  A_PRECISION_TYPE.VALUE_SRC USER
  C_A_EXPONENT_WIDTH.VALUE_SRC USER
  C_A_FRACTION_WIDTH.VALUE_SRC USER
  A_PRECISION_TYPE Custom
  C_A_EXPONENT_WIDTH 2
  C_A_FRACTION_WIDTH 30
  RESULT_PRECISION_TYPE Single
  HAS_ARESETN true
} {
  S_AXIS_A subset_1/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_1 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 64
} {
  S_AXIS fp_0/M_AXIS_RESULT
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster:1.1 bcast_8 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 64
  M_TDATA_NUM_BYTES 8
  NUM_MI 8
  M00_TDATA_REMAP {tdata[63:0]}
  M01_TDATA_REMAP {tdata[127:64]}
  M02_TDATA_REMAP {tdata[191:128]}
  M03_TDATA_REMAP {tdata[255:192]}
  M04_TDATA_REMAP {tdata[319:256]}
  M05_TDATA_REMAP {tdata[383:320]}
  M06_TDATA_REMAP {tdata[447:384]}
  M07_TDATA_REMAP {tdata[511:448]}
} {
  S_AXIS conv_1/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

for {set i 0} {$i <= 7} {incr i} {

  # Create fifo_generator
  cell xilinx.com:ip:fifo_generator:13.2 fifo_generator_$i {
    PERFORMANCE_OPTIONS First_Word_Fall_Through
    INPUT_DATA_WIDTH 64
    INPUT_DEPTH 512
    OUTPUT_DATA_WIDTH 32
    OUTPUT_DEPTH 1024
    READ_DATA_COUNT true
    READ_DATA_COUNT_WIDTH 11
  } {
    clk /pll_0/clk_out1
    srst slice_0/dout
  }

  # Create axis_fifo
  cell pavel-demin:user:axis_fifo:1.0 fifo_[expr $i + 1] {
    S_AXIS_TDATA_WIDTH 64
    M_AXIS_TDATA_WIDTH 32
  } {
    S_AXIS bcast_8/M0${i}_AXIS
    FIFO_READ fifo_generator_$i/FIFO_READ
    FIFO_WRITE fifo_generator_$i/FIFO_WRITE
    aclk /pll_0/clk_out1
  }

  # Create axi_axis_reader
  cell pavel-demin:user:axi_axis_reader:1.0 reader_$i {
    AXI_DATA_WIDTH 32
  } {
    S_AXIS fifo_[expr $i + 1]/M_AXIS
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

}
