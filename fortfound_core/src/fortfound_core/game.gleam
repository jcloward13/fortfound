import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/set.{type Set}

import fortfound_core/model.{
  type Card, type Game, type Location, type MajorArcanaFoundation,
  type MinorArcanaFoundation, type Move, type State, type Suit,
  BlockingMinorArcanaFoundation, Clubs, Coins, Column, Cups, Game, MajorArcana,
  MajorArcanaFoundation, MinorArcana, MinorArcanaFoundation, Move, State, Swords,
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

fn distribute_cards(cards: List(Card)) -> Dict(Int, List(Card)) {
  let columns = cards |> list.shuffle |> list.sized_chunk(7)

  let left_columns = columns |> list.take(5)
  let right_columns = columns |> list.drop(5)
  let all_columns = list.flatten([left_columns, [[]], right_columns])

  all_columns
  |> list.index_map(fn(column, index) { #(index, column) })
  |> dict.from_list
}

pub fn init() -> Game {
  let current_state =
    State(
      major_arcana_foundation: MajorArcanaFoundation(low: None, high: None),
      minor_arcana_foundation: MinorArcanaFoundation(
        coins: 1,
        swords: 1,
        clubs: 1,
        cups: 1,
        blocking: None,
      ),
      columns: generate_all_cards() |> distribute_cards(),
    )

  // Do not accept initial state where some cards can immediately go to foundations.
  case find_ready_for_foundation(current_state) {
    Ok(_) -> init()
    _ -> Game(current_state:, moved_card: None, previous_state: None)
  }
}

fn are_consecutive(n1: Int, n2: Int) -> Bool {
  int.absolute_value(n1 - n2) == 1
}

fn are_stackable(c1: Card, c2: Card) -> Bool {
  case c1, c2 {
    MajorArcana(v1), MajorArcana(v2) -> are_consecutive(v1, v2)
    MinorArcana(suit: s1, value: v1), MinorArcana(suit: s2, value: v2) ->
      s1 == s2 && are_consecutive(v1, v2)
    _, _ -> False
  }
}

fn get_column(state: State, index: Int) -> List(Card) {
  let assert Ok(column) = dict.get(state.columns, index)
  column
}

fn get_card(state: State, loc: Location) -> Result(Card, Nil) {
  case loc {
    BlockingMinorArcanaFoundation ->
      state.minor_arcana_foundation.blocking
      |> option.to_result(Nil)

    Column(index) ->
      get_column(state, index)
      |> list.first

    _ -> panic
  }
}

fn update_blocker(state: State, card: Option(Card)) -> State {
  State(
    ..state,
    minor_arcana_foundation: MinorArcanaFoundation(
      ..state.minor_arcana_foundation,
      blocking: card,
    ),
  )
}

fn update_column(
  state: State,
  at index: Int,
  with func: fn(List(Card)) -> List(Card),
) -> State {
  State(
    ..state,
    columns: dict.insert(
      into: state.columns,
      for: index,
      insert: get_column(state, index) |> func,
    ),
  )
}

fn remove_card(state: State, loc: Location) -> State {
  case loc {
    BlockingMinorArcanaFoundation -> state |> update_blocker(None)
    Column(index) -> state |> update_column(at: index, with: list.drop(_, 1))
    _ -> panic
  }
}

fn pop_card(state: State, loc: Location) -> Result(#(Card, State), Nil) {
  case get_card(state, loc) {
    Ok(card) -> Ok(#(card, remove_card(state, loc)))
    _ -> Error(Nil)
  }
}

fn put_card(state: State, card: Card, in loc: Location) -> State {
  case loc {
    BlockingMinorArcanaFoundation -> state |> update_blocker(Some(card))
    Column(index) ->
      state |> update_column(at: index, with: list.prepend(_, card))
    _ -> panic
  }
}

fn is_valid(state: State, move: Move) -> Bool {
  let selected = get_card(state, move.source)
  case selected, move.target {
    Error(Nil), _ -> False

    _, BlockingMinorArcanaFoundation ->
      state.minor_arcana_foundation.blocking |> option.is_none

    Ok(card), Column(index) -> {
      case get_column(state, index) {
        [] -> True
        [topmost, ..] -> are_stackable(card, topmost)
      }
    }

    _, _ -> panic
  }
}

fn next_low_major_arcana(state: State) -> Int {
  state.major_arcana_foundation.low
  |> option.map(int.add(_, 1))
  |> option.unwrap(or: 0)
}

fn next_high_major_arcana(state: State) -> Int {
  state.major_arcana_foundation.high
  |> option.map(int.subtract(_, 1))
  |> option.unwrap(or: 21)
}

fn next_minor_arcana(state: State, suit: Suit) -> Int {
  case suit {
    Coins -> state.minor_arcana_foundation.coins + 1
    Swords -> state.minor_arcana_foundation.swords + 1
    Clubs -> state.minor_arcana_foundation.clubs + 1
    Cups -> state.minor_arcana_foundation.cups + 1
  }
}

fn is_ready_for_foundation(state: State, card: Card) -> Bool {
  case card, state.minor_arcana_foundation.blocking {
    MajorArcana(value), _ -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)
      value == expected_low || value == expected_high
    }
    MinorArcana(..), Some(_) -> False
    MinorArcana(suit, value), None -> value == next_minor_arcana(state, suit)
  }
}

fn find_ready_for_foundation(state: State) -> Result(Location, Nil) {
  let locations = [
    BlockingMinorArcanaFoundation,
    ..state.columns
    |> dict.keys()
    |> list.map(Column)
  ]

  list.find(locations, fn(loc) {
    case get_card(state, loc) {
      Ok(card) -> is_ready_for_foundation(state, card)
      _ -> False
    }
  })
}

fn move_to_foundation(state: State, card: Card) -> State {
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
      State(..state, major_arcana_foundation: new)
    }

    MinorArcana(suit, value) -> {
      let current = state.minor_arcana_foundation
      let new = case suit {
        Coins -> MinorArcanaFoundation(..current, coins: value)
        Swords -> MinorArcanaFoundation(..current, swords: value)
        Clubs -> MinorArcanaFoundation(..current, clubs: value)
        Cups -> MinorArcanaFoundation(..current, cups: value)
      }
      State(..state, minor_arcana_foundation: new)
    }
  }
}

fn apply_colaterals(state: State) -> State {
  case find_ready_for_foundation(state) {
    Ok(location) -> {
      let assert Ok(#(card, state_without_card)) = pop_card(state, location)
      let new_state = state_without_card |> move_to_foundation(card)
      apply_colaterals(new_state)
    }
    _ -> state
  }
}

pub fn try_make_move(state: State, move: Move) -> #(State, Option(Card)) {
  case is_valid(state, move) {
    True -> {
      let assert Ok(#(selected, state)) = pop_card(state, move.source)

      let #(new_state, _) =
        state
        |> put_card(selected, in: move.target)
        // Repeat to move whole stacks.
        |> try_make_move(move)

      #(new_state, Some(selected))
    }
    False -> #(apply_colaterals(state), None)
  }
}

fn is_won(state: State) -> Bool {
  case state.major_arcana_foundation.low, state.major_arcana_foundation.high {
    Some(low), Some(high) -> low + 1 == high
    _, _ -> False
  }
  && state.minor_arcana_foundation.coins == 13
  && state.minor_arcana_foundation.swords == 13
  && state.minor_arcana_foundation.clubs == 13
  && state.minor_arcana_foundation.cups == 13
}

fn valid_moves(state: State) -> List(Move) {
  let locations = [
    BlockingMinorArcanaFoundation,
    ..list.range(0, 10)
    |> list.map(Column)
  ]

  locations
  |> list.combination_pairs
  |> list.map(fn(loc_pair) {
    let #(source, destination) = loc_pair
    Move(source, destination)
  })
  |> list.filter(is_valid(state, _))
}

fn score(state: State) -> Int {
  let empty_columns =
    state.columns
    |> dict.values
    |> list.count(list.is_empty)

  let major_arcanas_in_foundation =
    case state.major_arcana_foundation.low {
      Some(value) -> value + 1
      _ -> 0
    }
    + case state.major_arcana_foundation.high {
      Some(value) -> 21 - value + 1
      _ -> 0
    }

  let minor_arcanas_in_foundation =
    state.minor_arcana_foundation.coins
    + state.minor_arcana_foundation.swords
    + state.minor_arcana_foundation.clubs
    + state.minor_arcana_foundation.cups

  empty_columns * 10 + major_arcanas_in_foundation + minor_arcanas_in_foundation
}

pub fn is_winnable(state: State) -> Bool {
  is_winnable_aux(state, set.new())
}

pub fn is_winnable_aux(state: State, previous_states: Set(State)) -> Bool {
  case is_won(state) {
    True -> True
    _ -> {
      let next_states =
        valid_moves(state)
        |> list.map(fn(move) {
          let #(state, _) = try_make_move(state, move)
          state
        })

      let previous_states = previous_states |> set.insert(state)

      next_states
      |> list.filter(fn(state) { !set.contains(previous_states, state) })
      // Sorting is not a valid optimization if most states are unwinnable.
      // On unwinnable states we must try everything anyway...
      |> list.sort(
        by: fn(s1, s2) { int.compare(score(s1), score(s2)) }
        |> order.reverse,
      )
      |> list.any(is_winnable_aux(_, previous_states))
    }
  }
}
