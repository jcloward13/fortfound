import fortfound_core/game
import fortfound_core/scenarios
import startest
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn winnable_example_test() {
  scenarios.winnable_example()
  |> game.is_winnable
  |> expect.to_be_true
}

pub fn won_test() {
  scenarios.won_example()
  |> game.is_winnable
  |> expect.to_be_true
}

pub fn trivially_winnable_test() {
  scenarios.trivially_winnable_example()
  |> game.is_winnable
  |> expect.to_be_true
}
