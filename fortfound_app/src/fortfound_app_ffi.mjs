function get_svg() {
    return document.getElementsByTagName("svg")[0];
}

export function screen_to_svg_percentage(vector) {
    let svg = get_svg();
    let screen_to_svg_matrix = svg.getScreenCTM().inverse();

    let point = svg.createSVGPoint();
    point.x = vector.x;
    point.y = vector.y;

    let new_point = point.matrixTransform(screen_to_svg_matrix);

    let view_box = svg.viewBox.baseVal;

    return {
        x: new_point.x / view_box.width,
        y: new_point.y / view_box.height,
    };
}

export function percentage_to_absolute(vector) {
    let svg = get_svg();
    let view_box = svg.viewBox.baseVal;

    return {
        x: vector.x * view_box.width,
        y: vector.y * view_box.height,
    };
}
