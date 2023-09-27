// Copyright © Diem Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::account_address::AccountAddress;
use move_core_types::{
    ident_str,
    language_storage::{StructTag, TypeTag},
};
use once_cell::sync::Lazy;

use diem_enum_conversion_derive::name_coin;

// NOTE: this expands into:
// static COIN_MODULE: &'static str = $RUST_DIEM_COIN_MODULE;
// static COIN_NAME: &'static str = $RUST_DIEM_COIN_NAME;

name_coin!{}

pub static DIEM_COIN_TYPE: Lazy<TypeTag> = Lazy::new(|| {
    TypeTag::Struct(Box::new(StructTag {
        address: AccountAddress::ONE,
        module: ident_str!(COIN_MODULE).to_owned(), //////// 0L //////// a number of API endpoint (e.g. simulate_gas) will check for the coin resource and are looking for a specific name, so we're changing this to the generic coin name
        name: ident_str!(COIN_NAME).to_owned(), //////// 0L ////////
        type_params: vec![],
    }))
});
