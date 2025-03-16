import fortfound_app/engine
import fortfound_app/game
import fortfound_app/styles
import kitten/vec2.{Vec2}

pub fn main() -> Nil {
  engine.run(
    game.init,
    game.update,
    game.view,
    canvas_id: "canvas",
    world_size: Vec2(1920.0, 1080.0),
    background: styles.background_color(),
  )
}
