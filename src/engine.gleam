import gleam/function.{identity}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import kitten/canvas
import kitten/color.{type Color}
import kitten/draw
import kitten/mouse
import kitten/simulate
import kitten/vec2.{type Vec2, Vec2}
import plinth/browser/window

pub type Object(loc) {
  Object(
    loc: loc,
    position: Vec2,
    size: Vec2,
    draw: fn(Object(loc), draw.Context) -> Nil,
    clickable: Bool,
    draggable: Bool,
    targettable: Bool,
  )
}

type DraggedObject(loc) {
  DraggedObject(
    object: Object(loc),
    cursor_offset: Vec2,
    original_position: Vec2,
  )
}

type State(game, loc) {
  State(
    game_state: game,
    update_game: fn(game, Event(loc)) -> game,
    view_game: fn(game) -> List(Object(loc)),
    static_objects: List(Object(loc)),
    dragged_object: Option(DraggedObject(loc)),
    background: Color,
  )
}

fn init(
  init_game: fn() -> game,
  update_game: fn(game, Event(loc)) -> game,
  view_game: fn(game) -> List(Object(loc)),
  background: Color,
) -> State(game, loc) {
  let game_state = init_game()
  State(
    game_state:,
    update_game:,
    view_game:,
    static_objects: view_game(game_state),
    dragged_object: None,
    background:,
  )
}

pub type Event(loc) {
  Clicked(loc)
  Released(dragged: loc, target: loc)
}

fn try_release_dragged_object(
  state: State(game, loc),
) -> #(State(game, loc), Option(Event(loc))) {
  case state.dragged_object {
    Some(dragged) -> {
      let target =
        state.static_objects
        |> list.find(fn(other) {
          other.targettable
          && simulate.is_overlapping(
            dragged.object.position,
            dragged.object.size,
            other.position,
            other.size,
          )
        })

      let #(new_position, event) = case target {
        Ok(target) -> #(
          target.position,
          Some(Released(dragged.object.loc, target.loc)),
        )
        _ -> #(dragged.original_position, None)
      }

      let released_object = Object(..dragged.object, position: new_position)
      let new_state =
        State(
          ..state,
          static_objects: [released_object, ..state.static_objects],
          dragged_object: None,
        )

      #(new_state, event)
    }

    _ -> #(state, None)
  }
}

fn try_move_dragged_object(state: State(game, loc)) -> State(game, loc) {
  case state.dragged_object {
    Some(dragged) -> {
      let new_position = mouse.pos() |> vec2.subtract(dragged.cursor_offset)
      let object = Object(..dragged.object, position: new_position)
      State(..state, dragged_object: Some(DraggedObject(..dragged, object:)))
    }
    _ -> state
  }
}

fn try_grab_object(state: State(game, loc)) -> State(game, loc) {
  let mouse_pos = mouse.pos()

  let hovered =
    state.static_objects
    |> list.find(fn(object) {
      object.draggable
      && simulate.is_within(mouse_pos, object.position, object.size)
    })

  case hovered {
    Ok(object) -> {
      let static_objects =
        state.static_objects
        |> list.filter(fn(other) { other != object })

      let dragged_object =
        Some(DraggedObject(
          object:,
          cursor_offset: mouse_pos |> vec2.subtract(object.position),
          original_position: object.position,
        ))

      State(..state, static_objects:, dragged_object:)
    }
    _ -> state
  }
}

fn update_game_with_event(
  state_event_pair: #(State(game, loc), Option(Event(loc))),
) -> State(game, loc) {
  let #(state, event) = state_event_pair
  case event {
    Some(event) -> {
      let game_state = state.update_game(state.game_state, event)
      let static_objects = state.view_game(game_state)

      State(..state, game_state:, static_objects:)
    }
    _ -> state
  }
}

fn no_effect(state: State(game, loc)) -> #(State(game, loc), Option(Event(loc))) {
  #(state, None)
}

fn update(state: State(game, loc)) -> State(game, loc) {
  state
  |> case mouse.was_released(mouse.LMB) {
    True -> try_release_dragged_object
    _ -> no_effect
  }
  |> update_game_with_event
  |> case mouse.was_pressed(mouse.LMB) {
    True -> try_grab_object
    _ -> identity
  }
  |> try_move_dragged_object
  // TODO: handle Clicked event
}

fn view(state: State(game, loc)) -> Nil {
  let context =
    draw.context()
    |> draw.background(state.background)

  state.static_objects
  |> list.reverse
  |> list.each(fn(object) { object.draw(object, context) })

  case state.dragged_object {
    Some(DraggedObject(object, ..)) -> object.draw(object, context)
    None -> Nil
  }

  Nil
}

fn get_window_size() -> Vec2 {
  let window = window.self()

  Vec2(
    window.inner_width(window) |> int.to_float,
    window.inner_height(window) |> int.to_float,
  )
}

fn scale_to_fit(content_size: Vec2, viewport_size: Vec2) -> Vec2 {
  let viewport_ratio = viewport_size.x /. viewport_size.y
  let content_ratio = content_size.x /. content_size.y

  case viewport_ratio >=. content_ratio {
    True -> Vec2(content_size.y *. viewport_ratio, content_size.y)
    False -> Vec2(content_size.x, content_size.x /. viewport_ratio)
  }
}

pub fn run(
  init_game: fn() -> game_state,
  update_game: fn(game_state, Event(obj_id)) -> game_state,
  view_game: fn(game_state) -> List(Object(obj_id)),
  canvas_id canvas_id: String,
  world_size world_size: Vec2,
  background background_color: Color,
) {
  let window_size = get_window_size()
  let canvas_size = world_size |> scale_to_fit(window_size)

  canvas.start_window(
    fn() { init(init_game, update_game, view_game, background_color) },
    update,
    view,
    canvas_id:,
    canvas_width: canvas_size.x,
    canvas_height: canvas_size.y,
    image_sources: [],
    sound_sources: [],
  )
}
