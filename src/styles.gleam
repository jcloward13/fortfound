import gleam/int
import kitten/color
import kitten/draw
import kitten/vec2.{type Vec2, Vec2}
import model.{
  type Card, type Suit, Clubs, Coins, Cups, MajorArcana, MinorArcana, Swords,
}

pub const card_size = Vec2(150.0, 260.0)

fn card_vertices(position: Vec2) -> List(Vec2) {
  let Vec2(x, y) = position

  let half_size = card_size |> vec2.scale(0.5)
  let Vec2(half_width, half_height) = half_size

  [
    Vec2(x -. half_width, y +. half_height),
    position |> vec2.add(half_size),
    Vec2(x +. half_width, y -. half_height),
    position |> vec2.subtract(half_size),
    Vec2(x -. half_width, y +. half_height),
  ]
}

pub fn draw_slot(position: Vec2, context: draw.Context) -> Nil {
  let assert Ok(stroke_color) = color.from_hex("#8d693b")

  context
  |> draw.path(card_vertices(position), width: 3.0, color: stroke_color)
  Nil
}

fn suit_color(suit: Suit) -> String {
  case suit {
    Clubs -> "#497327"
    Coins -> "#956f3f"
    Cups -> "#963728"
    Swords -> "#326973"
  }
}

pub fn suit_icon(suit: Suit) -> String {
  case suit {
    Clubs -> "🌿"
    Coins -> "🪙"
    Cups -> "🍷"
    Swords -> "⚔️"
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

pub fn draw_card(card: Card, position: Vec2, context: draw.Context) -> Nil {
  let assert Ok(fill_color) =
    case card {
      MajorArcana(_) -> "#282523"
      MinorArcana(_, _) -> "#f8e3c1"
    }
    |> color.from_hex

  let assert Ok(stroke_color) =
    case card {
      MajorArcana(_) -> "#eea96b"
      MinorArcana(suit, _) -> suit_color(suit)
    }
    |> color.from_hex

  context
  |> draw.rect(position, size: card_size, color: fill_color)
  |> draw.path(card_vertices(position), width: 3.0, color: stroke_color)
  |> draw.text(
    card_text(card),
    position |> vec2.add(Vec2(0.0, 100.0)),
    size: 28.0,
    weight: 900.0,
    font: "Verdana",
    tilt: 0.0,
    color: stroke_color,
  )
  Nil
}

pub fn card_position(column_index: Int, card_index: Int) -> Vec2 {
  let x = int.to_float(column_index - 5) *. card_size.x *. 1.25
  let y = 200.0 -. int.to_float(card_index) *. card_size.y /. 7.0
  Vec2(x, y)
}
