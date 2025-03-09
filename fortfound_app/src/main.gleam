import fortfound_app/engine
import fortfound_app/game
import fortfound_core/game as core_game
import kitten/color
import kitten/vec2.{Vec2}

pub fn main() -> Nil {
  let assert Ok(background) = color.from_hex("#302017")

  engine.run(
    core_game.init,
    game.update,
    game.view,
    canvas_id: "canvas",
    world_size: Vec2(1920.0, 1080.0),
    background:,
  )
}
