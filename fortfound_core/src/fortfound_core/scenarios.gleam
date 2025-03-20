import fortfound_core/model.{
  type State, MajorArcana, MajorArcanaFoundation, MinorArcanaFoundation, State,
}
import fortfound_core/rng.{type Seed}
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/time/timestamp
import prng/random
import prng/seed

pub fn won_example() -> State {
  State(
    major_arcana_foundation: MajorArcanaFoundation(
      low: Some(10),
      high: Some(11),
    ),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 13,
      swords: 13,
      clubs: 13,
      cups: 13,
      blocking: None,
    ),
    columns: dict.from_list([
      #(0, []),
      #(1, []),
      #(2, []),
      #(3, []),
      #(4, []),
      #(5, []),
      #(6, []),
      #(7, []),
      #(8, []),
      #(9, []),
      #(10, []),
    ]),
  )
}

pub fn trivially_winnable_example() -> State {
  State(
    major_arcana_foundation: MajorArcanaFoundation(low: Some(8), high: Some(13)),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 13,
      swords: 13,
      clubs: 13,
      cups: 13,
      blocking: None,
    ),
    columns: dict.from_list([
      #(0, [MajorArcana(10), MajorArcana(9)]),
      #(1, [MajorArcana(11), MajorArcana(12)]),
      #(2, []),
      #(3, []),
      #(4, []),
      #(5, []),
      #(6, []),
      #(7, []),
      #(8, []),
      #(9, []),
      #(10, []),
    ]),
  )
}

const winnable_seeds = [
  "YY5V3B", "AWLQU5", "FBPRDO", "M2W1J2", "SLSB4S", "PM6Z75", "5QTD5E", "GNZ3E8",
  "8KJY0R", "KSUDRF", "5VRKNO", "IXCY4W", "7KBROT", "FQGH2A", "5X7KET", "KOQMIU",
  "SQ7QOU", "9YPO9B", "S5W5AU", "KE3D5X", "P8O0GB", "2TYOVC", "IUS9ZJ", "YS928L",
  "TD6K4N", "PG6FXA", "00SY4G", "0QP39M", "94ZLTV", "FB56E4", "LRHMD5", "8XK7PC",
  "QA5TR6", "VT3VWQ", "R4NGUF", "5B7JAK", "3R81ME", "FHW1V3", "UA6ZSK", "8OUM7T",
  "RAB93D", "WE2TW2", "FU5QSK", "GVHB03", "BQ1161", "8A2L13", "DCFSOW", "2LBPD1",
  "44YKYJ", "AM66G9", "19E26Q", "06L85E", "157R9S", "UP1H4Q", "ALJRP4", "P3IKG9",
  "RNVTJI", "1PY6A8", "B6ZA75", "1U5EZE", "QDK4ZW", "6OEF6O", "H7IA0O", "HYNE5M",
  "LRK1X5", "K2TPCX", "BJ7H9A", "NK6NMB", "6L5W5Q", "QW122R", "9IB6W9", "QZA6KK",
  "YCA5UJ", "MYJG96", "6PNM1S", "HE39MI", "24RHR2", "XH6K0Y", "EQLMMS", "D2BU9O",
  "7ULZ3L", "HLVMM5", "6S0NC1", "0X3TQL", "OP8TR8", "FASLE4", "4EUXFJ", "RZQ643",
  "IHG3M2", "O7HJRS", "XVM1T4", "QSTTS2", "9DK09Z", "BEW7Z8", "SAE5X3", "DJFFSZ",
  "5ZNV06", "NO5IL1", "HG0DWR", "AH5LAV", "XNEZ0L", "Z51FQY", "5FDXOU", "JXJWN3",
  "WMLKRA", "E1JPMY", "YQ7V1W", "EW3UQ6", "A1MY28", "WNI9HY", "GOTEB4", "EAAYJ1",
  "L9TG8Y", "O4IPJV", "UA766C", "JFB7BS", "3NNLX0", "RK3LSD", "I6BJ1I", "K0GLK0",
  "5BGBWS", "VGQ6QT", "SDU5EH", "A18VAW", "J7C0I0", "67QO5D", "M0QWD9", "CJ7MK4",
  "MJ0C9G", "0FPNAE", "TBTM7A", "VLGDDZ", "VK5DHI", "1AF5LM", "02GKMO", "MRGHC8",
  "TFMQZS", "E620SS", "T8LN8L", "UTY3Y4", "L0VKXB", "EDAPE7", "Q7LP6H", "HK549P",
  "OFMRFK", "WSE9JS", "5E7LNX", "BXQLPO", "0L6DZC", "89WR93", "GEGNBO", "CW21O1",
  "LH5TPX", "6G5LLO", "IWB6Y8", "Y9M6PA", "0ZIYTQ", "8CE7KO", "JQOPXS", "AQLJCA",
  "XY853D", "FHZA73", "IOMN9P", "9TCZ59", "LKVLIV", "RU0UA9", "1X2UCR", "USJDBV",
  "0EEDDX", "B9TSMA", "P1YYI5", "C4OXYM", "WUO5MH", "DI1QIQ", "H8ENJS", "MZ3023",
  "9OS5YJ", "T10TPE", "H988L4", "M77J9C", "E8F6JX", "6VFM0J", "LU1PBU", "UJTGOO",
  "OW8UQU", "D1U4N0", "DRZUPY", "J83EGL", "0VBWY4", "XBB9I8", "6N9GNZ", "KN3ZAH",
  "CW1P6H", "W2D7AM", "KO4V8P", "SUMJGF", "NUDS9J", "DC4T4W", "OG9OUO", "GVL3AR",
  "S02QAB", "8CQYYG", "0IE1MV", "BXYI98", "8D5MRC", "3FUQGH", "SLWGNW", "1OIXCO",
  "44Q5VF", "5TYCT0", "CDPIAA", "3UYPFB", "MTYKP5", "CUVHS9", "4REFCK", "HAJFQX",
  "K8JFTB", "YOZ6IC", "52HDUX", "56BMX6", "K38K9T", "RBR4ZT", "P32QSP", "OJQI0X",
  "75Q8EF", "BD4PCJ", "60AGHI", "WVYD0A", "QAL4HN", "13IV67", "GVBK8J", "C206CD",
  "D99L4V", "1AYV8Y", "XP6UFP", "5VOJ10", "KWRF8T", "WMF2T2", "WHBJ2S", "W0FO99",
  "N4DQJX", "2BYMHT", "BBR04J", "ELSG36", "P86SWR", "DT5Y4N", "79VSDK", "7TX8MO",
  "XLUBDW", "FGRLKM", "B7YXPD", "XCNE13", "7B7VW9", "OGWODC", "EJVQY9", "GNUI5S",
  "BO09RC", "7JEJL8", "IGXTOQ", "TLB2UI", "T9M02T", "UOU0VU", "72KB1H", "Y20AY2",
  "RSMO0G", "R1ZXZA", "BHF085", "45ULBG", "45GXX7", "J99C8L", "KTDKCC", "JF5AJB",
  "8I67X6", "IQINNY", "ONIMOZ", "R2DNYE", "8ZZ60X", "J0RL1U", "5X88Z9", "AU9Y1O",
  "7UXU35", "6E4GNW", "QNIZB4", "KX39GT", "I2EAX0", "AEMAZQ", "95RGAS", "4LF3UQ",
  "KZUV1Q", "R67V2F", "YZ8388", "PMZVKX", "NKG1CJ", "PJ645S", "O2XHEJ", "2Z2OFE",
  "5W30ES", "BOUHPK", "ODWCYN", "YDZKZZ", "PQORQR", "Z364ZT", "V7I5DT", "MBYBEP",
  "J2MI4Y", "QKQ8M7", "SC9RFC", "R7VSVC", "EMPOGI", "5W9FPX", "LO5RY0", "22R8D9",
  "Y7GB8T", "AYF1ST", "11B3YM", "2NZ3RA", "B1E4DB", "35MJOT", "XNZFJ9", "VJCDS6",
  "CPLY9J", "U8DU2B", "EJPEWH", "RO055A", "8J7ZQ3", "AZH6OU", "RHPN64", "JD71K7",
  "E5EHMZ", "46KTMC", "OBNLJY", "1VIBCR", "LVTOQJ", "KJLSSO", "DEQSXT", "SZ9NOH",
  "RIZIX8", "F7PW4B", "Z0DVLK", "4FGD33", "OSA6W5", "CK64TX", "G4K9K8", "DX3V48",
  "I4CPMT", "14XB80", "TZIBXS", "0BJCLG", "C5Q49R", "OCIRTR", "68MBUH", "T6NK56",
  "Z4QG8Q", "KTTT64", "E9EZRH", "KCH6HX", "TTWWBY", "G2IN3B", "MCSLX6", "AJRS0O",
  "UDVT2U", "T1WGRM", "COU5O6", "3DSLO0", "EC9PLA", "F2FS0P", "GLMH4F", "U8NNZN",
  "68ABKP", "R1S4ZP", "LQVD6H", "F48WWP", "XS93C7", "U7ZNSJ", "4ZHQQV", "ONS59F",
  "E2MSQY", "AH0COM", "QT2LOI", "FTJ5Z8", "UWUA0T", "477C70", "FW1LB9", "EYTFFL",
  "RCFU0A", "C69C5R", "N2FXFW", "QEX4MK", "K7IBOJ", "T0UPYA", "QE2WFW", "XQDZDY",
  "HBKCUH", "FRI1WJ", "M89FK0", "OFOBQ8", "56NF8Q", "CRSO8O", "T5001W", "HG4WT7",
  "70XPDP", "R2NTQM", "GDNYUK", "E9HSLP", "TUYKRY", "QFLNCT", "0I1B2F", "87UL2U",
  "LD9FAS", "FHHG67", "2RZR5C", "AC9ZN1", "6MBC3J", "FSAHGJ", "BLQ3FR", "5FNM6M",
  "24EI7Y", "2KRZVP", "VUW5QJ", "YOP1QC", "EU642D", "4PKG37", "09ES6V", "S01QJ7",
  "AMSFPT", "TI6P2H", "JG7JX4", "8CYLT4", "82QLO4", "TIU78P", "AIK2DZ", "DU1U2V",
  "HIOF30", "L8WMS2", "0EX9TH", "RXNU6Q", "DGZ9EQ", "C2AKH9", "5NZYQ9", "VXMDB0",
  "05N2RM", "CRXTDK", "JYSRVJ", "O6OHG4", "HZ0777", "2NQSIU", "7NBIBY", "Q5PX5L",
  "5B4T4C", "XN40KK", "3SDZX2", "D3IGX4", "7UA569", "I35IFW", "70O9R9", "KGR1GN",
  "I1ZC1W", "Z9NOZG", "GWBLBN", "9VG0SU", "P6KI7F", "MXS2Q2", "L82DTD", "2ML2CL",
  "AG5BDI", "NV5AU0", "S91BRR", "S0EHZN", "W5S4EN", "QZ8FES", "53LX9L", "KON3QI",
  "C7ECVJ", "E2DQH6", "LCCBLF", "LX24BF", "1LDRO6", "MWHC7U", "729AHX", "GIP0TQ",
  "J98LL1", "GPPOC0", "86952T", "XNP9GL", "S0T51V", "7BHC60", "QCZB0C", "5CTNNX",
  "QF98ZG", "70D5AD", "1ZSJI4", "56NGBE", "WF0FYR", "NH90OI", "HG37X7", "YYTFWO",
  "Y6JPKC", "A28RU9", "CGXOMZ", "5F5NYM",
]

pub fn random_winnable_scenario() -> Seed {
  let n = list.length(winnable_seeds)

  let assert Ok(encoded_seed) =
    winnable_seeds
    |> list.drop(int.random(n - 1))
    |> list.first

  let assert Ok(seed) = rng.decode_seed(encoded_seed)
  seed
}

pub fn current_daily_scenario() -> Seed {
  let seconds_in_day = 60 * 60 * 24

  let assert Ok(unix_day) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds
    |> float.round
    |> int.divide(seconds_in_day)

  let index =
    random.int(0, list.length(winnable_seeds) - 1)
    |> random.sample(seed.new(unix_day))

  let assert Ok(seed) =
    winnable_seeds
    |> list.drop(index)
    |> list.first
    |> result.then(rng.decode_seed)

  seed
}
