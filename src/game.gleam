import engine
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import model.{
  type Card, type Location, type Move, type State, type Suit,
  BlockingMinorArcanaFoundation, Clubs, Coins, Column, Cups, MajorArcana,
  MajorArcanaFoundation, MinorArcana, MinorArcanaFoundation, Move, State, Swords,
}
import styles

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
  let all_columns = list.append(left_columns, [[], ..right_columns])

  all_columns
  |> list.index_map(fn(column, index) { #(index, column) })
  |> dict.from_list
}

pub fn init() -> State {
  let state =
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
      previous_state: None,
    )

  // Do not accept initial state where some cards can immediately go to foundations.
  case find_ready_for_foundation(state) {
    Ok(_) -> init()
    Error(_) -> state
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
  }
}

fn pop_card(state: State, loc: Location) -> Result(#(Card, State), Nil) {
  use card <- result.map(get_card(state, loc))
  let new_state = remove_card(state, loc)
  #(card, new_state)
}

fn put_card(state: State, card: Card, in loc: Location) -> State {
  case loc {
    BlockingMinorArcanaFoundation -> state |> update_blocker(Some(card))
    Column(index) ->
      state |> update_column(at: index, with: list.prepend(_, card))
  }
}

pub fn is_valid(state: State, move: Move) -> Bool {
  use <- bool.guard(move.source == move.target, False)

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
  case card {
    MajorArcana(value) -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)
      value == expected_low || value == expected_high
    }
    MinorArcana(suit, value) -> value == next_minor_arcana(state, suit)
  }
}

fn find_ready_for_foundation(state: State) -> Result(Location, Nil) {
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

pub fn try_make_move(state: State, move: Move) -> State {
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

pub fn update(state: State, event: engine.Event(Location)) -> State {
  case event {
    engine.Clicked(_location) -> todo
    engine.Released(source, target) ->
      try_make_move(state, Move(source, target))
  }
}

fn view_cards(
  column_index: Int,
  cards: List(Card),
) -> List(engine.Object(Location)) {
  // Topmost card last.
  let last_card_index = list.length(cards) - 1
  let cards = list.reverse(cards)
  use card, card_index <- list.index_map(cards)

  engine.Object(
    loc: Column(column_index),
    position: styles.card_position(column_index, card_index),
    size: styles.card_size,
    draw: fn(obj, context) { styles.draw_card(card, obj.position, context) },
    clickable: card_index == last_card_index,
    draggable: card_index == last_card_index,
    targettable: card_index == last_card_index,
  )
}

fn view_column(column: #(Int, List(Card))) -> List(engine.Object(Location)) {
  let #(column_index, cards) = column

  case cards {
    [] -> [
      engine.Object(
        loc: Column(column_index),
        position: styles.card_position(column_index, 0),
        size: styles.card_size,
        draw: fn(obj, context) { styles.draw_slot(obj.position, context) },
        clickable: False,
        draggable: False,
        targettable: True,
      ),
    ]
    _ -> view_cards(column_index, cards) |> list.reverse
  }
}

pub fn view(state: State) -> List(engine.Object(Location)) {
  state.columns
  |> dict.to_list
  |> list.flat_map(view_column)
  // TODO: Draw foundations.
}
