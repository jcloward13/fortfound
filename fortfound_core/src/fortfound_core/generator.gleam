import fortfound_core/game
import fortfound_core/serde
import gleam/io

pub fn main() {
  let game = game.random_winnable_game()
  serde.encode_state(game.current_state) |> io.debug

  main()
}
