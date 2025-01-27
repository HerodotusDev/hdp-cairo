use axum::Json;
use cairo_vm::vm::runners::cairo_pie::CairoPie;
use types::HDPInput;

pub async fn root(Json(value): Json<HDPInput>) -> Json<CairoPie> {
    todo!()
}
