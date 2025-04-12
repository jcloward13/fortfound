import fortfound_core/game.{empty_game, game_from_seed, get_card, make_move}
import fortfound_core/model.{
  type Card, type Game, type Location, type MajorArcanaFoundation,
  type MinorArcanaFoundation, type Suit, BlockingMinorArcanaFoundation, Clubs,
  Coins, Column, Cups, Game, HistoryStep, MajorArcana, MinorArcana, Move, Swords,
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
import gleam_community/colour.{type Colour}
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
  case model, msg |> echo {
    _, RequestedNewGame(scenario) -> {
      let seed = case scenario {
        Random -> scenarios.random_winnable_scenario()
        Daily -> scenarios.current_daily_scenario()
        Specific(seed) -> seed
      }
      #(Model(game_from_seed(seed), None), set_seed_in_uri(seed))
    }

    Model(game: Game(seed: Some(seed), ..), ..), PressedRestart -> {
      #(Model(game_from_seed(seed), None), effect.none())
    }

    Model(selected: None, ..), GrabbedCard(source:, position:, pointer_offset:) -> {
      let model = case get_card(model.game.state, source) {
        Ok(card) -> {
          let selected =
            Some(Dragging(card:, from: source, position:, pointer_offset:))
          Model(..model, selected:)
        }
        _ -> model
      }
      #(model, effect.none())
    }

    Model(selected: Some(Dragging(..) as dragging), ..), MovedPointer(position) -> {
      let position = glector.add(position, dragging.pointer_offset)
      let selected = Some(Dragging(..dragging, position:))
      let model = Model(..model, selected:)
      #(model, effect.none())
    }

    Model(selected: Some(Dragging(..)), ..), ReleasedCard(target: None) -> #(
      Model(..model, selected: None),
      effect.none(),
    )

    Model(
      selected: Some(Dragging(from: source, ..)),
      ..,
    ),
      ReleasedCard(target: Some(target))
    -> {
      let model = case
        make_move(model.game, Move(source, target) |> echo) |> echo
      {
        Ok(game) -> Model(game:, selected: None)
        _ -> Model(..model, selected: None)
      }
      #(model, effect.none())
    }

    Model(selected: None, ..), Clicked(Some(location)) -> {
      let model = case get_card(model.game.state, location) {
        Ok(card) ->
          Model(..model, selected: Some(Highlighted(card:, location:)))
        _ -> model
      }
      #(model, effect.none())
    }

    Model(
      selected: Some(Highlighted(location: source, ..)),
      ..,
    ),
      Clicked(Some(target))
    -> {
      let model = case
        make_move(model.game, Move(source, target) |> echo) |> echo
      {
        Ok(game) -> Model(game:, selected: None)
        _ -> Model(..model, selected: None)
      }
      #(model, effect.none())
    }

    _, Clicked(None) -> #(Model(..model, selected: None), effect.none())

    Model(
      game: Game(
        history: [HistoryStep(state_before:, ..), ..previous_history],
        ..,
      ),
      ..,
    ),
      UndoMove
    -> {
      #(
        Model(
          ..model,
          game: Game(
            ..model.game,
            state: state_before,
            history: previous_history,
          ),
        ),
        effect.none(),
      )
    }

    _, _ -> #(model, effect.none())
  }
}

fn set_seed_in_uri(seed: Seed) -> Effect(Msg) {
  let query = "seed=" <> rng.encode_seed(seed)
  modem.push("", Some(query), None)
}

fn view(model: Model) -> Element(Msg) {
  let state = model.game.state

  [
    [
      view_buttons(),
      view_major_arcana_foundation(state.major_arcana_foundation),
      view_minor_arcana_foundation(
        state.minor_arcana_foundation,
        model.selected,
      ),
      ..state.columns
      |> dict.to_list
      |> list.map(view_column(_, model.selected))
    ],
    case model.game.history {
      [HistoryStep(moved:, ..), ..] -> [view_undo_button(moved)]
      _ -> []
    },
    case model.selected {
      Some(Dragging(card:, position:, ..)) -> [
        svg.g([attribute.style("pointer-events", "none")], [
          view_card(card, position, card_size(), None),
        ]),
      ]
      _ -> []
    },
  ]
  |> list.flatten
  |> svg(2000, 1000)
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
      on_event(TouchMove, MovedPointer),
      on_event(MouseMove, MovedPointer),
      on_event(MouseUp, fn(_) { ReleasedCard(None) }),
    ],
    elements,
  )
}

fn xy_pair_to_vector(xy: #(Float, Float)) -> Vector2 {
  let #(x, y) = xy
  Vector2(x, y)
}

@external(javascript, "./fortfound_app_ffi.mjs", "screen_to_svg_percentage")
fn screen_to_svg_percentage(vector: Vector2) -> Vector2

@external(javascript, "./fortfound_app_ffi.mjs", "percentage_to_absolute")
fn percentage_to_absolute(vector: Vector2) -> Vector2

type Event {
  TouchStart
  TouchMove
  TouchEnd
  MouseDown
  MouseMove
  MouseUp
  Click
}

fn on_event(event: Event, msg: fn(Vector2) -> Msg) -> Attribute(Msg) {
  let touch_decoder = decode.at(["touches", "0"], event.mouse_position())
  let mouse_decoder = event.mouse_position()

  let #(event_name, base_decoder) = case event {
    TouchStart -> #("touchstart", touch_decoder)
    TouchMove -> #("touchmove", touch_decoder)
    TouchEnd -> #("touchend", touch_decoder)
    MouseDown -> #("mousedown", mouse_decoder)
    MouseMove -> #("mousemove", mouse_decoder)
    MouseUp -> #("mouseup", mouse_decoder)
    Click -> #("click", mouse_decoder)
  }

  event.on(
    event_name,
    base_decoder
      |> decode.map(xy_pair_to_vector)
      |> decode.map(screen_to_svg_percentage)
      |> decode.map(msg),
  )
}

fn card_stroke(card: Card) -> Colour {
  let assert Ok(colour) =
    case card {
      MajorArcana(_) -> "#eea96b"
      MinorArcana(Clubs, _) -> "#497327"
      MinorArcana(Coins, _) -> "#956f3f"
      MinorArcana(Cups, _) -> "#963728"
      MinorArcana(Swords, _) -> "#326973"
    }
    |> colour.from_rgb_hex_string

  colour
}

fn card_fill(card: Card) -> Colour {
  let assert Ok(colour) =
    case card {
      MajorArcana(_) -> "#282523"
      MinorArcana(..) -> "#f8e3c1"
    }
    |> colour.from_rgb_hex_string

  colour
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

fn stroke_width() -> Float {
  3.5
}

fn origin_to_center(origin: Vector2, size: Vector2) -> Vector2 {
  glector.add(origin, glector.scale(size, 0.5))
}

fn center_to_origin(center: Vector2, size: Vector2) -> Vector2 {
  glector.subtract(center, glector.scale(size, 0.5))
}

fn percentage_attribute(name: String, value: Float) -> Attribute(Msg) {
  attr(name, float.to_string(value *. 100.0) <> "%")
}

fn card_size() -> Vector2 {
  let width = 1.0 /. 13.0
  let height = 0.24
  Vector2(x: width, y: height)
}

fn margin() -> Vector2 {
  Vector2(0.02, 0.02)
}

fn foundations_y() -> Float {
  margin().y
}

fn foundations_height() -> Float {
  card_size().y
}

fn stacked_card_offset() -> Float {
  card_size().y /. 6.0
}

fn card_padding() -> Float {
  stacked_card_offset() /. 6.0
}

fn tableau_width() -> Float {
  1.0 -. 2.0 *. margin().x
}

fn column_x(column: Int) -> Float {
  let card_size = card_size()
  let margin = margin()
  let tableau_width = tableau_width()

  let cards_total_width = card_size.x *. 11.0
  let card_margin = { tableau_width -. cards_total_width } /. 10.0

  margin.x +. { card_margin +. card_size.x } *. int.to_float(column)
}

fn major_arcana_foundation_xs() -> List(Float) {
  let first = column_x(0)
  let last = column_x(3)
  let offset = { last -. first } /. 21.0

  list.range(0, 21)
  |> list.map(int.to_float)
  |> list.map(fn(i) { first +. offset *. i })
}

fn minor_arcana_foundation_xs() -> List(Float) {
  list.range(7, 10) |> list.map(column_x)
}

fn tableau_start() -> Vector2 {
  let y = foundations_y() +. foundations_height() +. margin().y *. 2.0
  Vector2(0.0, y)
}

fn tableau_card_y(row: Int) -> Float {
  let offset = stacked_card_offset()
  tableau_start().y +. offset *. int.to_float(row)
}

fn view_major_arcana_foundation(
  foundation: MajorArcanaFoundation,
) -> Element(Msg) {
  let foundations_y = foundations_y()
  let column_xs = major_arcana_foundation_xs()
  let card_size = card_size()

  let lows = case foundation.low {
    Some(low) -> {
      list.range(0, low)
      |> list.map(MajorArcana)
      |> list.zip(column_xs)
      |> list.map(fn(card_and_x) {
        let #(card, x) = card_and_x
        let position = Vector2(x, foundations_y)
        view_card(card, position, card_size, None)
      })
    }
    None -> {
      let assert Ok(x) = list.first(column_xs)
      let position = Vector2(x, foundations_y)
      [view_slot(position, card_size, None)]
    }
  }

  let highs = case foundation.high {
    Some(high) -> {
      list.range(21, high)
      |> list.map(MajorArcana)
      |> list.zip(list.reverse(column_xs))
      |> list.map(fn(card_and_x) {
        let #(card, x) = card_and_x
        let position = Vector2(x, foundations_y)
        view_card(card, position, card_size, None)
      })
    }
    None -> {
      let assert Ok(x) = list.last(column_xs)
      let position = Vector2(x, foundations_y)
      [view_slot(position, card_size, None)]
    }
  }

  svg.g([], list.append(lows, highs))
}

fn view_minor_arcana_foundation(
  foundation: MinorArcanaFoundation,
  selected: Option(SelectedCard),
) -> Element(Msg) {
  let foundations_y = foundations_y()
  let column_xs = minor_arcana_foundation_xs()
  let card_size = card_size()

  let cards = [
    MinorArcana(Clubs, foundation.clubs),
    MinorArcana(Coins, foundation.coins),
    MinorArcana(Cups, foundation.cups),
    MinorArcana(Swords, foundation.swords),
  ]

  let center =
    Vector2(float.sum(column_xs) /. 4.0, foundations_y)
    |> glector.add(glector.scale(card_size, 0.5))

  let blocker = case foundation.blocker, selected {
    Some(blocker), Some(Dragging(card: dragging, ..)) if blocker == dragging ->
      element.none()
    Some(blocker), _ -> view_blocker(blocker, center)
    _, _ -> element.none()
  }

  let foundation_cards =
    cards
    |> list.zip(column_xs)
    |> list.map(fn(card_and_x) {
      let #(card, x) = card_and_x
      let position = Vector2(x, foundations_y)
      view_card(card, position, card_size, None)
    })

  let elements = list.reverse([blocker, ..foundation_cards])

  let loc = Some(BlockingMinorArcanaFoundation)
  let events = [
    on_event(MouseUp, fn(_) { ReleasedCard(target: loc) }),
    on_event(Click, fn(_) { Clicked(loc) }),
  ]

  svg.g(events, elements)
}

fn view_blocker(card: Card, foundation_center: Vector2) -> Element(Msg) {
  let card_size = card_size()
  let position = center_to_origin(foundation_center, card_size)

  svg.g([rotate(foundation_center, 90.0)], [
    view_card(card, position, card_size, Some(BlockingMinorArcanaFoundation)),
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
  selected: Option(SelectedCard),
) -> Element(Msg) {
  let #(column_index, cards) = column
  let x = column_x(column_index)
  let card_size = card_size()

  let loc = Column(column_index)

  [
    view_slot(Vector2(x, tableau_start().y), card_size, Some(loc)),
    ..cards
    |> list.reverse
    |> list.index_map(fn(card, row) { #(card, Vector2(x, tableau_card_y(row))) })
    |> list.filter_map(fn(card_and_position) {
      let #(card, position) = card_and_position
      let position = case selected {
        Some(Dragging(card: dragging, ..)) if card == dragging -> Error(Nil)
        Some(Highlighted(card: highlighted, ..)) if card == highlighted ->
          Ok(position |> glector.add(Vector2(0.0, stacked_card_offset())))
        _ -> Ok(position)
      }

      position
      |> result.map(view_card(card, _, card_size, Some(loc)))
    })
  ]
  |> svg.g([], _)
}

fn view_card(
  card: Card,
  position: Vector2,
  size: Vector2,
  loc: Option(Location),
) -> Element(Msg) {
  let padding = card_padding()

  let #(text_x, text_anchor, text_dx) = case card {
    MajorArcana(_) -> #(position.x +. size.x /. 2.0, "middle", 0.0)
    MinorArcana(..) -> #(position.x, "start", padding)
  }

  let fill = "#" <> colour.to_rgb_hex_string(card_fill(card))
  let stroke = "#" <> colour.to_rgb_hex_string(card_stroke(card))
  let text_color = stroke

  let rect =
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", fill),
      attr("stroke", stroke),
      attr("stroke-width", float.to_string(stroke_width())),
    ])

  let text =
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", position.y),
        percentage_attribute("dx", text_dx),
        percentage_attribute("dy", padding),
        attr("text-anchor", text_anchor),
        attr("dominant-baseline", "hanging"),
        attr("fill", text_color),
      ],
      card_text(card),
    )

  svg.g(
    case loc {
      Some(loc) -> [
        on_event(MouseDown, fn(mouse_pos) {
          GrabbedCard(
            source: loc,
            position:,
            pointer_offset: glector.subtract(position, mouse_pos),
          )
        }),
        on_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_event(Click, fn(_) { Clicked(Some(loc)) }),
      ]
      _ -> []
    },
    [rect, text],
  )
}

fn view_slot(
  position: Vector2,
  size: Vector2,
  target: Option(Location),
) -> Element(Msg) {
  svg.rect(
    [
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      // Must be transparent instead of 'none' otherwise events won't trigger.
      attr("fill", "#00000000"),
      attr("stroke", "#8d693b"),
      attr("stroke-width", float.to_string(stroke_width())),
    ]
    |> list.append(case target {
      Some(loc) -> [
        on_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_event(Click, fn(_) { Clicked(Some(loc)) }),
      ]
      None -> []
    }),
  )
}

fn button_size() -> Vector2 {
  let card_size = card_size()
  let width = card_size.x
  let height = card_size.y /. 2.0 -. margin().y /. 2.0
  Vector2(x: width, y: height)
}

fn view_button(
  text: String,
  position: Vector2,
  size: Vector2,
  msg: Msg,
) -> Element(Msg) {
  let text_x = position.x +. size.x /. 2.0
  let text_y = position.y +. size.y /. 2.0

  svg.g([attr("cursor", "pointer"), on_event(MouseDown, fn(_) { msg })], [
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", "#8d693b"),
    ]),
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", text_y),
        attr("text-anchor", "middle"),
        attr("dominant-baseline", "middle"),
        attr("fill", "#f8e3c1"),
      ],
      text,
    ),
  ])
}

fn button_positions() -> List(Vector2) {
  let left = column_x(4)
  let right = column_x(6)

  let top = foundations_y()
  let bottom = top +. button_size().y +. margin().y

  [
    Vector2(left, top),
    Vector2(left, bottom),
    Vector2(right, top),
    Vector2(right, bottom),
  ]
}

fn view_buttons() -> Element(Msg) {
  let buttons = {
    let specs =
      [
        #("New game", RequestedNewGame(Random)),
        #("Restart", PressedRestart),
        #("Daily", RequestedNewGame(Daily)),
        #("Help", PressedHelp),
      ]
      |> list.zip(button_positions())

    use #(#(text, msg), position) <- list.map(specs)
    view_button(text, position, button_size(), msg)
  }

  svg.g([], buttons)
}

fn view_undo_button(card: Card) -> Element(Msg) {
  let normal_card_size = card_size()
  let small_card_size = normal_card_size |> glector.scale(0.7)
  let button_size = button_size() |> glector.scale(0.8)

  let center =
    Vector2(column_x(5), foundations_y())
    |> origin_to_center(normal_card_size)

  let card_position = center_to_origin(center, small_card_size)
  let button_position = center_to_origin(center, button_size)

  svg.g([], [
    view_card(card, card_position, small_card_size, None),
    view_button("Undo", button_position, button_size, UndoMove),
  ])
}
