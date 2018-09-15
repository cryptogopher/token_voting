require File.expand_path('../../test_helper', __FILE__)

class TokenVotesNotifyTest < TokenVoting::NotificationIntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules,
    :trackers, :workflow_transitions

  def setup
    super
    setup_plugin

    @issue1 = issues(:issue_01)
    @issue2 = issues(:issue_02)
    @min_conf = token_types(:BTCREG).min_conf

    Rails.logger.info "TEST #{name}"
  end

  def teardown
    super
    logout_user
  end

  def test_rpc_get_tx_addresses
    address = @wallet.get_new_address
    txid = nil
    assert_notifications 'blocknotify' => 1 do
      txid = @network.send_to_address(address, 0.1)
      @network.generate(1)
    end
    assert txid

    inputs, outputs = @wallet.get_tx_addresses(txid)
    assert_includes [1, 2], outputs.length
    assert_includes outputs, address

    net_inputs, net_outputs = @network.get_tx_addresses(txid)
    assert_operator (net_inputs+inputs).uniq.to_set, :==, net_inputs.to_set
    assert_operator net_outputs.to_set, :==, outputs.to_set
  end

  def test_rpc_send_from_address
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    vote2 = create_token_vote

    assert_operator min_conf = vote1.token_type.min_conf, :>, 2
    assert_notifications 'blocknotify' => min_conf do
      @network.send_to_address(vote1.address, 1.45)
      @network.generate(min_conf)
    end
    [vote1, vote2].map(&:reload)
    assert_equal 0, vote1.amount_unconf
    assert_equal 1.45, vote1.amount_conf

    assert_notifications 'blocknotify' => min_conf do
      txid = @wallet.send_from_address(vote1.address, vote2.address, 0.6)
      assert_in_mempool @network, txid
      @network.send_to_address(vote1.address, 0.12)
      @network.generate(min_conf)
    end
    [vote1, vote2].map(&:reload)
    assert_equal 0.97, vote1.amount_conf
    assert_equal 0.599, vote2.amount_conf
  end

  def test_rpc_get_normalized_txid_for_all_address_types
    ['legacy', 'p2sh-segwit', 'bech32'].each do |address_type|
      from_address = @network.get_new_address('', address_type)
      to_address = @network.get_new_address('', address_type)

      assert_notifications 'blocknotify' => 1 do
        txid = @network.send_to_address(from_address, 0.1)
        assert txid
        @network.generate(1)
      end
      utxos = @network.list_unspent(1, 9999999, [from_address])
      amount = utxos.sum { |utxo| utxo['amount'] }
      outputs = {to_address => amount - 0.0001}

      rtx = @network.create_raw_transaction(utxos, outputs)
      unsigned_ntxid = @network.get_normalized_txid(rtx)
      stx = @network.sign_raw_transaction(rtx)
      signed_ntxid = @network.get_normalized_txid(stx['hex'])
      assert_equal unsigned_ntxid, signed_ntxid

      txid = nil
      assert_notifications 'blocknotify' => 1 do
        txid = @network.send_raw_transaction(stx['hex'])
        assert txid
        assert_in_mempool @wallet, txid
        @network.generate(1)
      end
      confirmed_tx = @wallet.get_raw_transaction(txid, true)
      assert confirmed_tx

      confirmed_ntxid = @wallet.get_normalized_txid(confirmed_tx)
      assert_equal unsigned_ntxid, confirmed_ntxid
    end
  end
end

