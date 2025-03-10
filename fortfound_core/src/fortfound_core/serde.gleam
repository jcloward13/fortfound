import fortfound_core/game
import fortfound_core/model.{
  type Card, type State, type Suit, Clubs, Coins, Cups, MajorArcana, MinorArcana,
  State, Swords,
}
import gleam/bit_array
import gleam/dict
import gleam/int
import gleam/list
import gleam/pair
import gleam/result
import gleam/string

fn encode_suit(suit: Suit) -> String {
  case suit {
    Clubs -> "P"
    Coins -> "O"
    Cups -> "C"
    Swords -> "E"
  }
}

fn decode_suit(char: String) -> Result(Suit, Nil) {
  case char {
    "P" -> Ok(Clubs)
    "O" -> Ok(Coins)
    "C" -> Ok(Cups)
    "E" -> Ok(Swords)
    _ -> Error(Nil)
  }
}

fn encode_minor_arcana_value(value: Int) -> String {
  case value {
    1 -> "A"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "0"
    11 -> "J"
    12 -> "Q"
    13 -> "K"
    _ -> panic
  }
}

fn decode_minor_arcana_value(char: String) -> Result(Int, Nil) {
  case char {
    "A" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "0" -> Ok(10)
    "J" -> Ok(11)
    "Q" -> Ok(12)
    "K" -> Ok(13)
    _ -> Error(Nil)
  }
}

fn encode_card(card: Card) -> String {
  case card {
    MajorArcana(value) ->
      int.to_string(value) |> string.pad_start(to: 2, with: "0")
    MinorArcana(suit, value) ->
      encode_suit(suit) <> encode_minor_arcana_value(value)
  }
}

fn decode_card(chars: List(String)) -> Result(Card, Nil) {
  case chars {
    [a, b] ->
      case decode_suit(a), decode_minor_arcana_value(b) {
        Ok(suit), Ok(value) -> Ok(MinorArcana(suit, value))
        _, _ -> int.parse(a <> b) |> result.map(MajorArcana)
      }
    _ -> Error(Nil)
  }
}

pub fn encode_state(state: State) -> String {
  state.columns
  |> dict.to_list
  |> list.sort(fn(index_and_column1, index_and_column2) {
    int.compare(index_and_column1.0, index_and_column2.0)
  })
  |> list.flat_map(pair.second)
  |> list.map(encode_card)
  |> string.join("")
  |> bit_array.from_string
  |> bit_array.base64_url_encode(False)
}

pub fn decode_state(string: String) -> Result(State, Nil) {
  case
    string
    |> bit_array.base64_url_decode
    |> result.then(bit_array.to_string)
  {
    Ok(string) -> {
      string
      |> string.to_graphemes
      |> list.sized_chunk(2)
      |> list.map(decode_card)
      |> result.all
      |> result.map(game.distribute_cards)
      |> result.map(fn(columns) { State(..game.empty_state(), columns:) })
    }
    Error(_) -> Error(Nil)
  }
}
