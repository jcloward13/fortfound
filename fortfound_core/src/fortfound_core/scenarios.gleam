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
