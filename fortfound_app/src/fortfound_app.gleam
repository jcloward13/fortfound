import fortfound_app/layout.{type Layout}
import fortfound_app/palette
import fortfound_core/game.{empty_game, game_from_seed, get_card, make_move}
import fortfound_core/model.{
  type Card, type Game, type Location, type MajorArcanaFoundation,
  type MinorArcanaFoundation, type Suit, BlockingMinorArcanaFoundation, Clubs,
  Coins, Column, Cups, Game, HistoryStep, MajorArcana, MinorArcana, Move, State,
  Swords,
}
import fortfound_core/rng.{type Seed}
import fortfound_core/scenarios
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import glector.{type Vector2, Vector2}
import lustre
import lustre/attribute.{type Attribute, attribute as attr}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event
import modem

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type SelectedCard {
  Dragging(
    card: Card,
    from: Location,
    position: Vector2,
    pointer_offset: Vector2,
  )
  Highlighted(card: Card, location: Location)
}

type Model {
  Model(game: Game, selected: Option(SelectedCard))
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let game =
    modem.initial_uri()
    |> result.then(parse_seed)
    |> result.map(game_from_seed)
    |> result.lazy_unwrap(empty_game)

  #(Model(game, None), effect.none())
}

fn parse_seed(uri: Uri) -> Result(Seed, Nil) {
  use query <- result.try(
    uri.query
    |> option.to_result(Nil)
    |> result.then(uri.parse_query),
  )

  query
  |> dict.from_list
  |> dict.get("seed")
  |> result.then(rng.decode_seed)
}

type Scenario {
  Random
  Daily
  Specific(Seed)
}

type Msg {
  RequestedNewGame(Scenario)
  PressedRestart
  PressedHelp
  GrabbedCard(source: Location, position: Vector2, pointer_offset: Vector2)
  MovedPointer(Vector2)
  ReleasedCard(target: Option(Location))
  Clicked(Option(Location))
  UndoMove
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    RequestedNewGame(scenario) -> {
      let seed = case scenario {
        Random -> scenarios.random_winnable_scenario()
        Daily -> scenarios.current_daily_scenario()
        Specific(seed) -> seed
      }
      let new_model = Model(game_from_seed(seed), None)
      #(new_model, set_seed_in_uri(seed))
    }

    PressedRestart -> {
      let new_model = case model.game.seed {
        None -> Model(game: empty_game(), selected: None)
        Some(seed) -> Model(game_from_seed(seed), selected: None)
      }
      #(new_model, effect.none())
    }

    GrabbedCard(source:, position:, pointer_offset:) -> {
      let grabbed_card = get_card(model.game.state, source)
      let new_model = case model.selected, grabbed_card {
        None, Ok(card) -> {
          let dragging =
            Dragging(card:, from: source, position:, pointer_offset:)
          Model(..model, selected: Some(dragging))
        }
        _, _ -> model
      }
      #(new_model, effect.none())
    }

    MovedPointer(position) -> {
      let new_model = case model.selected {
        Some(Dragging(..) as dragging) -> {
          let position = glector.add(position, dragging.pointer_offset)
          let dragging = Dragging(..dragging, position:)
          Model(..model, selected: Some(dragging))
        }
        _ -> model
      }
      #(new_model, effect.none())
    }

    ReleasedCard(target: None) -> {
      let new_model = case model.selected {
        Some(Dragging(..)) -> Model(..model, selected: None)
        _ -> model
      }
      #(new_model, effect.none())
    }

    ReleasedCard(target: Some(target)) -> {
      let new_model = case model.selected {
        Some(Dragging(from: source, ..)) ->
          case make_move(model.game, Move(source, target)) {
            Ok(game) -> Model(game:, selected: None)
            Error(Nil) -> Model(..model, selected: None)
          }
        _ -> model
      }
      #(new_model, effect.none())
    }

    Clicked(Some(target)) -> {
      let new_model = case model.selected {
        Some(Highlighted(location: source, ..)) -> {
          case make_move(model.game, Move(source, target)) {
            Ok(game) -> Model(game:, selected: None)
            Error(Nil) -> Model(..model, selected: None)
          }
        }

        _ -> {
          case get_card(model.game.state, target) {
            Ok(card) -> {
              let highlighted = Highlighted(card:, location: target)
              Model(..model, selected: Some(highlighted))
            }
            Error(Nil) -> model
          }
        }
      }
      #(new_model, effect.none())
    }

    Clicked(None) -> #(Model(..model, selected: None), effect.none())

    UndoMove -> {
      let new_model = case model.game.history {
        [HistoryStep(state_before:, ..), ..history] -> {
          let game = Game(..model.game, state: state_before, history:)
          Model(..model, game:)
        }
        [] -> model
      }
      #(new_model, effect.none())
    }

    // TODO
    PressedHelp -> #(model, effect.none())
  }
}

fn set_seed_in_uri(seed: Seed) -> Effect(Msg) {
  let query = "seed=" <> rng.encode_seed(seed)
  modem.push("", Some(query), None)
}

fn view(model: Model) -> Element(Msg) {
  let State(
    major_arcana_foundation: major,
    columns:,
    minor_arcana_foundation: minor,
  ) = model.game.state

  let layout = layout.get_layout()

  [
    case model.selected {
      Some(Dragging(card:, position:, ..)) ->
        view_dragged_card(card, position, layout)
      _ -> element.none()
    },
    view_major_arcana_foundation(major, layout),
    view_buttons(layout),
    case model.game.history {
      [HistoryStep(moved:, ..), ..] -> view_undo_button(moved, layout)
      _ -> element.none()
    },
    view_minor_arcana_foundation(minor, layout, model.selected),
    ..columns
    |> dict.to_list
    |> list.map(view_column(_, layout, model.selected))
  ]
  |> list.reverse
  |> svg(2000, 1000)
}

@external(javascript, "./fortfound_app_ffi.mjs", "screen_to_svg_percentage")
fn screen_to_svg_percentage(vector: Vector2) -> Vector2

@external(javascript, "./fortfound_app_ffi.mjs", "percentage_to_absolute")
fn percentage_to_absolute(vector: Vector2) -> Vector2

fn percentage_attribute(name: String, value: Float) -> Attribute(a) {
  attr(name, float.to_string(value *. 100.0) <> "%")
}

type MouseEvent {
  MouseDown
  MouseMove
  MouseUp
  MouseClick
}

fn on_mouse_event(event: MouseEvent, msg: fn(Vector2) -> Msg) -> Attribute(Msg) {
  let event_name = case event {
    MouseDown -> "mousedown"
    MouseMove -> "mousemove"
    MouseUp -> "mouseup"
    MouseClick -> "click"
  }

  event.on(
    event_name,
    event.mouse_position()
      |> decode.map(fn(xy) {
        let #(x, y) = xy
        Vector2(x, y)
      })
      |> decode.map(screen_to_svg_percentage)
      |> decode.map(msg),
  )
}

fn svg(elements: List(Element(Msg)), width: Int, height: Int) -> Element(Msg) {
  html.svg(
    [
      attr(
        "viewBox",
        [0, 0, width, height]
          |> list.map(int.to_string)
          |> string.join(" "),
      ),
      attribute.styles([
        #("width", "100%"),
        #("max-height", "100vh"),
        #("font-family", "Arima"),
        #("font-weight", "700"),
        #("font-size", "1.75em"),
        #("user-select", "none"),
      ]),
      on_mouse_event(MouseMove, MovedPointer),
      on_mouse_event(MouseUp, fn(_) { ReleasedCard(None) }),
    ],
    elements,
  )
}

fn stroke_width() -> Float {
  3.5
}

fn suit_icon(suit: Suit) -> String {
  case suit {
    Clubs -> "♣"
    Coins -> "♦"
    Cups -> "♥"
    Swords -> "♠"
  }
}

fn card_text(card: Card) -> String {
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
      <> suit_icon(suit)
  }
}

fn view_card(
  card card: Card,
  position position: Vector2,
  scale scale: Float,
  layout layout: Layout,
  loc loc: Option(Location),
) -> Element(Msg) {
  let size = layout.card_size |> glector.scale(scale)

  let #(text_x, text_anchor, text_dx) = case card {
    MajorArcana(_) -> #(position.x +. size.x /. 2.0, "middle", 0.0)
    MinorArcana(..) -> #(position.x, "start", layout.card_padding)
  }

  let fill_color = palette.card_fill(card)
  let main_color = palette.card_stroke(card)

  let rect =
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", fill_color),
      attr("stroke", main_color),
      attr("stroke-width", float.to_string(stroke_width())),
    ])

  let text =
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", position.y),
        percentage_attribute("dx", text_dx),
        percentage_attribute("dy", layout.card_padding),
        attr("text-anchor", text_anchor),
        attr("dominant-baseline", "hanging"),
        attr("fill", main_color),
      ],
      card_text(card),
    )

  svg.g(
    case loc {
      Some(loc) -> [
        on_mouse_event(MouseDown, fn(mouse_pos) {
          GrabbedCard(
            source: loc,
            position:,
            pointer_offset: glector.subtract(position, mouse_pos),
          )
        }),
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(Some(loc)) }),
      ]
      _ -> []
    },
    [rect, text],
  )
}

fn view_dragged_card(
  card: Card,
  position: Vector2,
  layout: Layout,
) -> Element(Msg) {
  svg.g([attribute.style("pointer-events", "none")], [
    view_card(card, position, 1.0, layout, None),
  ])
}

fn view_slot(
  position: Vector2,
  layout: Layout,
  target: Option(Location),
) -> Element(Msg) {
  svg.rect(
    [
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", layout.card_size.x),
      percentage_attribute("height", layout.card_size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", palette.slot_fill),
      attr("stroke", palette.slot_stroke),
      attr("stroke-width", float.to_string(stroke_width())),
    ]
    |> list.append(case target {
      Some(loc) -> [
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(Some(loc)) }),
      ]
      None -> []
    }),
  )
}

fn view_button(
  text: String,
  position: Vector2,
  size: Vector2,
  msg: Msg,
) -> Element(Msg) {
  let text_x = position.x +. size.x /. 2.0
  let text_y = position.y +. size.y /. 2.0

  svg.g([attr("cursor", "pointer"), on_mouse_event(MouseDown, fn(_) { msg })], [
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", palette.button_fill),
    ]),
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", text_y),
        attr("text-anchor", "middle"),
        attr("dominant-baseline", "middle"),
        attr("fill", palette.button_text),
      ],
      text,
    ),
  ])
}

fn view_buttons(layout: Layout) -> Element(Msg) {
  let buttons = {
    let specs =
      [
        #("New game", RequestedNewGame(Random)),
        #("Restart", PressedRestart),
        #("Daily", RequestedNewGame(Daily)),
        #("Help", PressedHelp),
      ]
      |> list.zip(layout.button_positions(layout))

    use #(#(text, msg), position) <- list.map(specs)
    view_button(text, position, layout.button_size, msg)
  }

  svg.g([], buttons)
}

fn view_undo_button(card: Card, layout: Layout) -> Element(Msg) {
  let card_scale = 0.7
  let button_size = layout.button_size |> glector.scale(0.8)

  let center =
    Vector2(layout.column_x(5, layout), layout.foundations_y)
    |> layout.origin_to_center(layout.card_size)

  let card_position =
    layout.center_to_origin(center, glector.scale(layout.card_size, card_scale))
  let button_position = layout.center_to_origin(center, button_size)

  svg.g([], [
    view_card(card, card_position, scale: card_scale, layout:, loc: None),
    view_button("Undo", button_position, button_size, UndoMove),
  ])
}

fn view_major_arcana_foundation(
  foundation: MajorArcanaFoundation,
  layout: Layout,
) -> Element(Msg) {
  let column_xs = layout.major_arcana_foundation_xs(layout)

  let lows = case foundation.low {
    Some(low) -> {
      list.range(0, low)
      |> list.map(MajorArcana)
      |> list.zip(column_xs)
      |> list.map(fn(card_and_x) {
        let #(card, x) = card_and_x
        let position = Vector2(x, layout.foundations_y)
        view_card(card:, position:, scale: 1.0, layout:, loc: None)
      })
    }
    None -> {
      let assert Ok(x) = list.first(column_xs)
      let position = Vector2(x, layout.foundations_y)
      [view_slot(position, layout, None)]
    }
  }

  let highs = case foundation.high {
    Some(high) -> {
      list.range(21, high)
      |> list.map(MajorArcana)
      |> list.zip(list.reverse(column_xs))
      |> list.map(fn(card_and_x) {
        let #(card, x) = card_and_x
        let position = Vector2(x, layout.foundations_y)
        view_card(card:, position:, scale: 1.0, layout:, loc: None)
      })
    }
    None -> {
      let assert Ok(x) = list.last(column_xs)
      let position = Vector2(x, layout.foundations_y)
      [view_slot(position, layout, None)]
    }
  }

  svg.g([], list.append(lows, highs))
}

fn view_minor_arcana_foundation(
  foundation: MinorArcanaFoundation,
  layout: Layout,
  selected: Option(SelectedCard),
) -> Element(Msg) {
  let column_xs = layout.minor_arcana_foundation_xs(layout)

  let cards = [
    MinorArcana(Clubs, foundation.clubs),
    MinorArcana(Coins, foundation.coins),
    MinorArcana(Cups, foundation.cups),
    MinorArcana(Swords, foundation.swords),
  ]

  let center =
    Vector2(float.sum(column_xs) /. 4.0, layout.foundations_y)
    |> glector.add(glector.scale(layout.card_size, 0.5))

  let blocker = case foundation.blocker, selected {
    Some(blocker), Some(Dragging(card: dragging, ..)) if blocker == dragging ->
      element.none()
    Some(blocker), _ -> view_blocker(blocker, center, layout)
    _, _ -> element.none()
  }

  let foundation_cards =
    cards
    |> list.zip(column_xs)
    |> list.map(fn(card_and_x) {
      let #(card, x) = card_and_x
      let position = Vector2(x, layout.foundations_y)
      view_card(card:, position:, scale: 1.0, layout:, loc: None)
    })

  let elements = list.reverse([blocker, ..foundation_cards])

  let loc = Some(BlockingMinorArcanaFoundation)
  let events = [
    on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: loc) }),
    on_mouse_event(MouseClick, fn(_) { Clicked(loc) }),
  ]

  svg.g(events, elements)
}

fn view_blocker(
  card: Card,
  foundation_center: Vector2,
  layout: Layout,
) -> Element(Msg) {
  let position = layout.center_to_origin(foundation_center, layout.card_size)

  svg.g([rotate(foundation_center, 90.0)], [
    view_card(
      card:,
      position:,
      scale: 1.0,
      layout:,
      loc: Some(BlockingMinorArcanaFoundation),
    ),
  ])
}

fn rotate(position: Vector2, degrees: Float) -> Attribute(Msg) {
  let position = percentage_to_absolute(position)
  let rotation_values =
    [degrees, position.x, position.y]
    |> list.map(float.to_string)
    |> string.join(", ")

  attr("transform", "rotate(" <> rotation_values <> ")")
}

fn view_column(
  column: #(Int, List(Card)),
  layout: Layout,
  selected: Option(SelectedCard),
) -> Element(Msg) {
  let #(column_index, cards) = column

  let x = layout.column_x(column_index, layout)
  let loc = Some(Column(column_index))

  let slot = view_slot(Vector2(x, layout.tableau_start.y), layout, loc)

  let cards =
    cards
    |> list.reverse
    |> list.index_map(fn(card, row) {
      let y = layout.tableau_card_y(row, layout)
      let position = case selected {
        Some(Dragging(card: dragging, ..)) if card == dragging -> Error(Nil)
        Some(Highlighted(card: highlighted, ..)) if card == highlighted -> {
          let offset = Vector2(0.0, layout.stacked_card_y_offset)
          Ok(Vector2(x, y) |> glector.add(offset))
        }
        _ -> Ok(Vector2(x, y))
      }
      #(card, position)
    })
    |> list.filter_map(fn(card_and_position) {
      let #(card, position) = card_and_position
      use position <- result.map(position)
      view_card(card:, position:, scale: 1.0, layout:, loc:)
    })

  svg.g([], [slot, ..cards])
}
