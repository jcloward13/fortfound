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
    blocker: Option(Card),
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

pub type HistoryStep {
  HistoryStep(moved: Card, state_before: State)
}

pub type Game {
  Game(seed: Option(Seed), state: State, history: List(HistoryStep))
}

pub type Location {
  Column(Int)
  BlockingMinorArcanaFoundation
}

pub type MoveRequest {
  MoveRequest(source: Location, target: Location)
}

pub type PartialMove {
  PartialMove(source: Location, card: Card, target: Location)
}

pub type MoveToFoundation {
  MoveToFoundation(source: Location, card: Card)
}

pub type FullMove {
  FullMove(
    requested: PartialMove,
    stacked: List(PartialMove),
    to_foundations: List(MoveToFoundation),
  )
}
