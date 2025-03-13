import fortfound_core/game.{random_winnable_game}
import fortfound_core/model.{type Game}
import fortfound_core/rng
import gleam/io
import gleam/list
import gleam/otp/task.{type Task}

fn generate_n_games(n: Int) -> List(Task(Game)) {
  list.range(1, n)
  |> list.map(fn(_) { task.async(random_winnable_game) })
}

pub fn main() {
  use task <- list.each(generate_n_games(72))
  let game = task.await_forever(task)
  game.seed
  |> rng.encode_seed
  |> io.println
}
