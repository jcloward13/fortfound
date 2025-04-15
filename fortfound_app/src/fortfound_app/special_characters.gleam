import fortfound_core/model.{type Suit, Clubs, Coins, Cups, Swords}

/// This function stays in its own separate module to avoid an LSP bug:
/// https://github.com/gleam-lang/gleam/issues/3628
pub fn suit_icon(suit: Suit) -> String {
  case suit {
    Clubs -> "♣"
    Coins -> "♦"
    Cups -> "♥"
    Swords -> "♠"
  }
}
