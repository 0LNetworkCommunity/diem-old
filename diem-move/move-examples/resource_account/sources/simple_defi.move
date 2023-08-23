/// This module demonstrates how to create a new coin and build simple defi swap functions for the new coin
/// using a resource account.
///
/// - Initialization of this module
/// Let's say we have an original account at address `0xcafe`. We can use it to call
/// `create_resource_account_and_publish_package(origin, vector::empty<>(), ...)` - this will create a resource account at
/// address `0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5`. The module `simple_defi` will be published
/// under the resource account's address.
///
/// - The basic flow
/// (1) call create_resource_account_and_publish_package() to publish this module under the resource account's address.
/// init_module() will be called with resource account's signer as part of publishing the package.
/// - In init_module(), we do two things: first, we create the new coin; secondly, we store the resource account's signer capability
/// and the coin's mint and burn capabilities within `ModuleData`. Storing the signer capability allows the module to programmatically
/// sign transactions without needing a private key
/// (2) when exchanging coins, we call `exchange_to` to swap `DiemCoin` to `ChloesCoin`, and `exchange_from` to swap `DiemCoin` from `ChloesCoin`
module resource_account::simple_defi {
    use std::signer;
    use std::string;

    use diem_framework::account;
    use diem_framework::coin::{Self, Coin, MintCapability, BurnCapability};
    use diem_framework::resource_account;
    use diem_framework::diem_coin::{DiemCoin};

    struct ModuleData has key {
        resource_signer_cap: account::SignerCapability,
        burn_cap: BurnCapability<ChloesCoin>,
        mint_cap: MintCapability<ChloesCoin>,
    }

    struct ChloesCoin {
        diem_coin: DiemCoin
    }

    /// initialize the module and store the signer cap, mint cap and burn cap within `ModuleData`
    fun init_module(account: &signer) {
        // store the capabilities within `ModuleData`
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(account, @source_addr);
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<ChloesCoin>(
            account,
            string::utf8(b"Chloe's Coin"),
            string::utf8(b"CCOIN"),
            8,
            false,
        );
        move_to(account, ModuleData {
            resource_signer_cap,
            burn_cap,
            mint_cap,
        });

        // destroy freeze cap because we aren't using it
        coin::destroy_freeze_cap(freeze_cap);

        // regsiter the resource account with both coins so it has a CoinStore to store those coins
        coin::register<DiemCoin>(account);
        coin::register<ChloesCoin>(account);
    }

    /// Exchange DiemCoin to ChloesCoin
    public fun exchange_to(a_coin: Coin<DiemCoin>): Coin<ChloesCoin> acquires ModuleData {
        let coin_cap = borrow_global_mut<ModuleData>(@resource_account);
        let amount = coin::value(&a_coin);
        coin::deposit(@resource_account, a_coin);
        coin::mint<ChloesCoin>(amount, &coin_cap.mint_cap)
    }

    /// Exchange ChloesCoin to DiemCoin
    public fun exchange_from(c_coin: Coin<ChloesCoin>): Coin<DiemCoin> acquires ModuleData {
        let amount = coin::value(&c_coin);
        let coin_cap = borrow_global_mut<ModuleData>(@resource_account);
        coin::burn<ChloesCoin>(c_coin, &coin_cap.burn_cap);

        let module_data = borrow_global_mut<ModuleData>(@resource_account);
        let resource_signer = account::create_signer_with_capability(&module_data.resource_signer_cap);
        coin::withdraw<DiemCoin>(&resource_signer, amount)
    }

    /// Entry function version of exchange_to() for e2e tests only
    public entry fun exchange_to_entry(account: &signer, amount: u64) acquires ModuleData {
        let a_coin = coin::withdraw<DiemCoin>(account, amount);
        let c_coin = exchange_to(a_coin);

        coin::register<ChloesCoin>(account);
        coin::deposit(signer::address_of(account), c_coin);
    }

    /// Entry function version of exchange_from() for e2e tests only
    public entry fun exchange_from_entry(account: &signer, amount: u64) acquires ModuleData {
        let c_coin = coin::withdraw<ChloesCoin>(account, amount);
        let a_coin = exchange_from(c_coin);

        coin::deposit(signer::address_of(account), a_coin);
    }

    #[test_only]
    public entry fun set_up_test(origin_account: &signer, resource_account: &signer) {
        use std::vector;

        account::create_account_for_test(signer::address_of(origin_account));

        // create a resource account from the origin account, mocking the module publishing process
        resource_account::create_resource_account(origin_account, vector::empty<u8>(), vector::empty<u8>());
        init_module(resource_account);
    }

    #[test(origin_account = @0xcafe, resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5, framework = @diem_framework)]
    public entry fun test_exchange_to_and_exchange_from(origin_account: signer, resource_account: signer, framework: signer) acquires ModuleData {
        use diem_framework::diem_coin;

        set_up_test(&origin_account, &resource_account);
        let (diem_coin_burn_cap, diem_coin_mint_cap) = diem_coin::initialize_for_test(&framework);

        // exchange from 5 diem coins to 5 chloe's coins & assert the results are expected
        let five_a_coins = coin::mint(5, &diem_coin_mint_cap);
        let c_coins = exchange_to(five_a_coins);
        assert!(coin::value(&c_coins) == 5, 0);
        assert!(coin::balance<DiemCoin>(signer::address_of(&resource_account)) == 5, 1);
        assert!(coin::balance<ChloesCoin>(signer::address_of(&resource_account)) == 0, 2);

        // exchange from 5 chloe's coins to 5 diem coins & assert the results are expected
        let a_coins = exchange_from(c_coins);
        assert!(coin::value(&a_coins) == 5, 0);
        assert!(coin::balance<DiemCoin>(signer::address_of(&resource_account)) == 0, 3);
        assert!(coin::balance<ChloesCoin>(signer::address_of(&resource_account)) == 0, 4);

        // burn the remaining coins & destroy the capabilities since they aren't droppable
        coin::burn(a_coins, &diem_coin_burn_cap);
        coin::destroy_mint_cap<DiemCoin>(diem_coin_mint_cap);
        coin::destroy_burn_cap<DiemCoin>(diem_coin_burn_cap);
    }
}
