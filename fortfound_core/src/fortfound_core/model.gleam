import fortfound_core/rng.{type Seed}
import gleam/dict.{type Dict}
import gleam/option.{type Option}

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

pub type State {
  State(
    major_arcana_foundation: MajorArcanaFoundation,
    minor_arcana_foundation: MinorArcanaFoundation,
    columns: Dict(Int, List(Card)),
  )
}

pub type Game {
  Game(
    seed: Seed,
    current_state: State,
    moved_card: Option(Card),
    previous_state: Option(State),
  )
}

pub type Location {
  Column(Int)
  BlockingMinorArcanaFoundation
  UndoButton
}

pub type Move {
  Move(source: Location, target: Location)
}
