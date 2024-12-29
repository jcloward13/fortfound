import game.{type Move, Column, MajorArcana, MinorArcana, Move, new_game}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/event
import sketch.{Ephemeral, cache}
import sketch/lustre as sketch_lustre
import sketch/lustre/element
import sketch/lustre/element/html
import sketch/size
import styles

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let assert Ok(cache) = cache(strategy: Ephemeral)

  sketch_lustre.node()
  |> sketch_lustre.compose(view, cache)
  |> lustre.simple(init, update, _)
  |> lustre.start("#app", Nil)
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(game_state: game.GameState, selected: Option(game.Location))
}

fn init(_flags) -> Model {
  Model(game_state: new_game(), selected: None)
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UserSelectedCard(location: game.Location)
  UserClickedEmptySlot(location: game.Location)
  UserClickedMinorArcanaFoundation
}

fn update(model: Model, msg: Msg) -> Model {
  case model.selected {
    None ->
      case msg {
        UserSelectedCard(location) -> model |> select(location)
        UserClickedEmptySlot(_) -> model
        UserClickedMinorArcanaFoundation ->
          case model.game_state.minor_arcana_foundation.blocking {
            Some(_) -> model |> select(game.BlockingMinorArcanaFoundation)
            None -> model
          }
      }
    Some(already_selected) ->
      case msg {
        UserSelectedCard(new_location) | UserClickedEmptySlot(new_location) ->
          model
          |> try_make_move(Move(already_selected, new_location))
          |> deselect()
        UserClickedMinorArcanaFoundation ->
          model
          |> try_make_move(Move(
            already_selected,
            game.BlockingMinorArcanaFoundation,
          ))
          |> deselect()
      }
  }
}

fn select(model: Model, location: game.Location) -> Model {
  Model(..model, selected: Some(location))
}

fn deselect(model: Model) -> Model {
  Model(..model, selected: None)
}

fn try_make_move(model: Model, move: Move) -> Model {
  Model(..model, game_state: game.try_make_move(model.game_state, move))
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> element.Element(Msg) {
  html.div(styles.background_class(), [], [
    view_major_arcana_foundation(model.game_state.major_arcana_foundation),
    view_minor_arcana_foundation(model.game_state.minor_arcana_foundation),
    view_tableau(model.game_state, model.selected),
  ])
}

fn view_major_arcana_foundation(
  foundation: game.MajorArcanaFoundation,
) -> element.Element(Msg) {
  let empty = fn(col: styles.GridColumn) {
    html.div(
      styles.composed([
        styles.grid_element_class(
          styles.grid_row_from_index(0, of: 1),
          col,
          styles.Horizontal,
          True,
        ),
        styles.empty_slot_class(),
      ]),
      [],
      [],
    )
  }

  let low_cards = case foundation.low {
    None -> [empty(styles.grid_column_from_index(0))]
    Some(max_low_value) ->
      list.range(0, max_low_value)
      |> list.map(fn(value) {
        view_card(
          MajorArcana(value),
          styles.GridRow(1),
          styles.grid_column_from_index(value),
          styles.Horizontal,
          value == max_low_value,
          False,
          UserClickedMinorArcanaFoundation,
        )
      })
  }

  let high_cards = case foundation.high {
    None -> [empty(styles.grid_column_from_index(21))]
    Some(min_high_value) ->
      list.range(21, min_high_value)
      |> list.map(fn(value) {
        view_card(
          MajorArcana(value),
          styles.GridRow(1),
          styles.grid_column_from_index(value),
          styles.Horizontal,
          value == min_high_value,
          False,
          UserClickedMinorArcanaFoundation,
        )
      })
  }

  html.div(
    styles.composed([styles.major_arcana_foundation_class()]),
    [],
    list.flatten([low_cards, high_cards]),
  )
}

fn view_minor_arcana_foundation(
  foundation: game.MinorArcanaFoundation,
) -> element.Element(Msg) {
  let cards = case foundation.blocking {
    Some(card) -> [
      view_card(
        card,
        styles.GridRow(1),
        styles.GridColumn(1),
        styles.Horizontal,
        True,
        False,
        UserClickedMinorArcanaFoundation,
      ),
    ]
    None ->
      foundation
      |> game.minor_arcana_foundation_cards()
      |> list.index_map(fn(card, index) {
        view_card(
          card,
          styles.GridRow(1),
          styles.grid_column_from_index(index),
          styles.Horizontal,
          True,
          False,
          UserClickedMinorArcanaFoundation,
        )
      })
  }

  html.div(
    styles.composed([
      sketch.class([sketch.max_width(size.percent(25))]),
      styles.minor_arcana_foundation_class(),
    ]),
    [],
    cards,
  )
}

fn view_tableau(
  game_state: game.GameState,
  selected: Option(game.Location),
) -> element.Element(Msg) {
  let cards =
    game_state.columns
    |> dict.to_list
    |> list.flat_map(fn(indexed_column) {
      let #(column_index, cards) = indexed_column
      view_card_column(
        cards,
        column_index,
        selected == Some(Column(column_index)),
      )
    })

  html.div(styles.tableau_class(), [], cards)
}

fn view_empty_slot(column_index: Int) -> element.Element(Msg) {
  html.div(
    styles.composed([
      styles.grid_element_class(
        styles.grid_row_from_index(0, of: 1),
        styles.grid_column_from_index(column_index),
        styles.Vertical,
        True,
      ),
      styles.empty_slot_class(),
    ]),
    [event.on_click(UserSelectedCard(Column(column_index)))],
    [],
  )
}

fn view_card_column(
  cards: List(game.Card),
  column_index: Int,
  is_selected: Bool,
) -> List(element.Element(Msg)) {
  case cards {
    [] -> [view_empty_slot(column_index)]
    _ -> {
      use card, index <- list.index_map(cards)
      let is_topmost = index == 0
      view_card(
        card,
        styles.grid_row_from_index(index, of: list.length(cards)),
        styles.grid_column_from_index(column_index),
        styles.Vertical,
        is_topmost,
        is_selected,
        UserSelectedCard(Column(column_index)),
      )
    }
  }
}

fn view_card(
  card: game.Card,
  row: styles.GridRow,
  col: styles.GridColumn,
  direction: styles.StackDirection,
  is_topmost: Bool,
  is_selected: Bool,
  if_selected: Msg,
) -> element.Element(Msg) {
  let arcana_class = case card {
    MajorArcana(_) -> styles.major_arcana_class()
    MinorArcana(suit, _) -> styles.minor_arcana_class(suit)
  }

  let grid_element_class =
    styles.grid_element_class(row, col, direction, is_topmost)

  let base_class =
    styles.composed([styles.card_class(), arcana_class, grid_element_class])

  let class = case is_selected && is_topmost {
    True -> styles.composed([base_class, styles.selected_class()])
    False -> base_class
  }

  let attributes = case is_topmost {
    False -> []
    True -> [event.on_click(if_selected)]
  }

  html.div(class, attributes, [element.text(card_text(card))])
}

fn card_text(card: game.Card) -> String {
  case card {
    MajorArcana(value) -> value |> int.to_string
    MinorArcana(suit, value) ->
      case value {
        1 -> "A"
        11 -> "J"
        12 -> "Q"
        13 -> "K"
        _ -> value |> int.to_string
      }
      <> styles.suit_icon(suit)
  }
}
