import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type Suit {
  Coins
  Swords
  Clubs
  Cups
}

pub type Card {
  MajorArcana(value: Int)
  MinorArcana(suit: Suit, value: Int)
}

fn generate_all_cards() -> List(Card) {
  let major_arcana =
    list.range(0, 21)
    |> list.map(MajorArcana)

  let minor_arcana = {
    use suit <- list.flat_map([Coins, Swords, Clubs, Cups])
    list.range(2, 13)
    |> list.map(MinorArcana(suit, _))
  }

  list.append(major_arcana, minor_arcana)
}

fn generate_columns() -> Dict(Int, List(Card)) {
  let columns = generate_all_cards() |> list.shuffle |> list.sized_chunk(7)

  let left_columns = columns |> list.take(5)
  let right_columns = columns |> list.drop(5)
  let all_columns = list.append(left_columns, [[], ..right_columns])

  all_columns
  |> list.index_map(fn(column, index) { #(index, column) })
  |> dict.from_list
}

pub type MajorArcanaFoundation {
  MajorArcanaFoundation(low: Option(Int), high: Option(Int))
}

pub type MinorArcanaFoundation {
  MinorArcanaFoundation(
    coins: Int,
    swords: Int,
    clubs: Int,
    cups: Int,
    blocking: Option(Card),
  )
}

pub fn minor_arcana_foundation_cards(
  foundation: MinorArcanaFoundation,
) -> List(Card) {
  [
    MinorArcana(Clubs, foundation.clubs),
    MinorArcana(Coins, foundation.coins),
    MinorArcana(Cups, foundation.cups),
    MinorArcana(Swords, foundation.swords),
  ]
}

pub type GameState {
  GameState(
    major_arcana_foundation: MajorArcanaFoundation,
    minor_arcana_foundation: MinorArcanaFoundation,
    columns: Dict(Int, List(Card)),
    previous_state: Option(GameState),
  )
}

pub fn new_game() -> GameState {
  let state =
    GameState(
      major_arcana_foundation: MajorArcanaFoundation(low: None, high: None),
      minor_arcana_foundation: MinorArcanaFoundation(
        coins: 1,
        swords: 1,
        clubs: 1,
        cups: 1,
        blocking: None,
      ),
      columns: generate_columns(),
      previous_state: None,
    )

  // Do not accept initial state where some cards can immediately go to foundations.
  case find_ready_for_foundation(state) {
    Ok(_) -> new_game()
    Error(_) -> state
  }
}

pub type Location {
  Column(Int)
  BlockingMinorArcanaFoundation
}

pub type Move {
  Move(source: Location, target: Location)
}

fn are_adjacent(n1: Int, n2: Int) -> Bool {
  int.absolute_value(n1 - n2) == 1
}

fn are_stackable(c1: Card, c2: Card) -> Bool {
  case c1, c2 {
    MajorArcana(v1), MajorArcana(v2) -> are_adjacent(v1, v2)
    MinorArcana(suit: s1, value: v1), MinorArcana(suit: s2, value: v2) ->
      s1 == s2 && are_adjacent(v1, v2)
    _, _ -> False
  }
}

fn can_stack(selected: Card, onto column: List(Card)) -> Bool {
  case column {
    [] -> True
    [topmost, ..] -> are_stackable(selected, topmost)
  }
}

fn get_column(state: GameState, index: Int) -> List(Card) {
  let assert Ok(column) = dict.get(state.columns, index)
  column
}

fn get_card(state: GameState, loc: Location) -> Result(Card, Nil) {
  case loc {
    BlockingMinorArcanaFoundation ->
      state.minor_arcana_foundation.blocking
      |> option.to_result(Nil)

    Column(index) ->
      get_column(state, index)
      |> list.first
  }
}

fn with_blocking_card(state: GameState, card: Option(Card)) -> GameState {
  GameState(
    ..state,
    minor_arcana_foundation: MinorArcanaFoundation(
      ..state.minor_arcana_foundation,
      blocking: card,
    ),
  )
}

fn with_updated_column(
  state: GameState,
  at index: Int,
  with func: fn(List(Card)) -> List(Card),
) -> GameState {
  GameState(
    ..state,
    columns: dict.insert(
      into: state.columns,
      for: index,
      insert: get_column(state, index) |> func,
    ),
  )
}

fn remove_card(state: GameState, loc: Location) -> GameState {
  case loc {
    BlockingMinorArcanaFoundation -> state |> with_blocking_card(None)
    Column(index) ->
      state |> with_updated_column(at: index, with: list.drop(_, 1))
  }
}

fn pop_card(state: GameState, loc: Location) -> Result(#(Card, GameState), Nil) {
  use card <- result.map(get_card(state, loc))
  let new_state = remove_card(state, loc)
  #(card, new_state)
}

fn put_card(state: GameState, card: Card, in loc: Location) -> GameState {
  case loc {
    BlockingMinorArcanaFoundation -> state |> with_blocking_card(Some(card))
    Column(index) ->
      state |> with_updated_column(at: index, with: list.prepend(_, card))
  }
}

pub fn is_valid(state: GameState, move: Move) -> Bool {
  use <- bool.guard(move.source == move.target, False)

  let selected = get_card(state, move.source)
  case selected, move.target {
    Error(Nil), _ -> False

    _, BlockingMinorArcanaFoundation ->
      state.minor_arcana_foundation.blocking |> option.is_none

    Ok(card), Column(index) -> {
      let column = get_column(state, index)
      can_stack(card, onto: column)
    }
  }
}

fn next_low_major_arcana(state: GameState) -> Int {
  state.major_arcana_foundation.low
  |> option.map(int.add(_, 1))
  |> option.unwrap(or: 0)
}

fn next_high_major_arcana(state: GameState) -> Int {
  state.major_arcana_foundation.high
  |> option.map(int.subtract(_, 1))
  |> option.unwrap(or: 21)
}

fn next_minor_arcana(state: GameState, suit: Suit) -> Int {
  case suit {
    Coins -> state.minor_arcana_foundation.coins + 1
    Swords -> state.minor_arcana_foundation.swords + 1
    Clubs -> state.minor_arcana_foundation.clubs + 1
    Cups -> state.minor_arcana_foundation.cups + 1
  }
}

fn is_ready_for_foundation(state: GameState, card: Card) -> Bool {
  case card {
    MajorArcana(value) -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)
      value == expected_low || value == expected_high
    }
    MinorArcana(suit, value) -> value == next_minor_arcana(state, suit)
  }
}

fn find_ready_for_foundation(state: GameState) -> Result(Location, Nil) {
  let locations = [
    BlockingMinorArcanaFoundation,
    ..state.columns
    |> dict.keys()
    |> list.map(Column)
  ]

  let minor_arcana_blocked =
    state.minor_arcana_foundation.blocking |> option.is_some()

  list.find_map(locations, fn(loc) {
    use card <- result.try(get_card(state, loc))
    case card, minor_arcana_blocked {
      MinorArcana(_, _), True -> Error(Nil)
      _, _ ->
        case is_ready_for_foundation(state, card) {
          True -> Ok(loc)
          False -> Error(Nil)
        }
    }
  })
}

fn with_added_to_foundation(state: GameState, card: Card) -> GameState {
  case card {
    MajorArcana(value) -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)

      let current = state.major_arcana_foundation
      let new = case value {
        _ if value == expected_low ->
          MajorArcanaFoundation(..current, low: Some(value))
        _ if value == expected_high ->
          MajorArcanaFoundation(..current, high: Some(value))
        _ -> panic
      }
      GameState(..state, major_arcana_foundation: new)
    }

    MinorArcana(suit, value) -> {
      let current = state.minor_arcana_foundation
      let new = case suit {
        Coins -> MinorArcanaFoundation(..current, coins: value)
        Swords -> MinorArcanaFoundation(..current, swords: value)
        Clubs -> MinorArcanaFoundation(..current, clubs: value)
        Cups -> MinorArcanaFoundation(..current, cups: value)
      }
      GameState(..state, minor_arcana_foundation: new)
    }
  }
}

fn apply_colaterals(state: GameState) -> GameState {
  case find_ready_for_foundation(state) {
    Ok(location) -> {
      let assert Ok(#(card, state_without_card)) = pop_card(state, location)
      let new_state = state_without_card |> with_added_to_foundation(card)
      apply_colaterals(new_state)
    }
    _ -> state
  }
}

pub fn try_make_move(state: GameState, move: Move) -> GameState {
  case is_valid(state, move) {
    True -> {
      let assert Ok(#(selected, state)) = pop_card(state, move.source)
      state
      |> put_card(selected, in: move.target)
      // Repeat to move whole stacks.
      |> try_make_move(move)
    }
    False -> apply_colaterals(state)
  }
}
