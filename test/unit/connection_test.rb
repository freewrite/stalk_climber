class ConnectionTest < Test::Unit::TestCase

  def setup
    @connection = StalkClimber::Connection.new('localhost:11300')
  end


  def test_cache_creates_and_returns_hash_instance_variable
    refute @connection.instance_variable_get(:@cache)
    assert_equal({}, @connection.cache)
    assert_equal({}, @connection.instance_variable_get(:@cache))
  end


  def test_connection_is_some_kind_of_enumerable
    assert @connection.kind_of?(Enumerable)
  end


  def test_each_caches_jobs_for_later_use
    jobs = {}
    @connection.each do |job|
      jobs[job[:id]] = job
    end

    @connection.expects(:with_job).never
    @connection.each do |job|
      assert_equal jobs[job[:id]], job
    end
  end


  def test_each_only_hits_each_job_once
    jobs = {}
    @connection.each do |job|
      refute jobs[job[:id]]
      jobs[job[:id]] = job
    end
  end


  def test_each_is_an_alias_for_climb
    assert_equal(
      StalkClimber::Connection.instance_method(:climb),
      StalkClimber::Connection.instance_method(:each),
      'Expected StalkClimber::Connection#each to be an alias for StalkClimber::Connection#climb'
    )
  end


  def test_job_exists
    probe = @connection.transmit(StalkClimber::Connection::PROBE_TRANSMISSION)
    id = probe[:id].to_i
    assert @connection.job_exists?(id)

    @connection.transmit("delete #{id}")
    refute @connection.job_exists?(id)
  end


  def test_max_job_id_returns_expected_max_job_id
    initial_max = @connection.max_job_id
    3.times do
      probe = @connection.transmit(StalkClimber::Connection::PROBE_TRANSMISSION)
      @connection.transmit("delete #{probe[:id]}")
    end
    # 3 new jobs, +1 for the probe job
    assert_equal initial_max + 4, @connection.max_job_id
  end


  def test_max_job_id_should_increment_max_climbed_id_if_successor
    @connection.each {}
    max = @connection.max_climbed_job_id
    @connection.max_job_id
    assert_equal max + 1, @connection.max_climbed_job_id
  end


  def test_max_job_id_should_not_increment_max_climbed_id_unless_successor
    @connection.each {}
    max = @connection.max_climbed_job_id
    probe = @connection.transmit(StalkClimber::Connection::PROBE_TRANSMISSION)
    @connection.transmit("delete #{probe[:id]}")
    @connection.max_job_id
    assert_equal max, @connection.max_climbed_job_id
  end


  def test_each_sets_min_and_max_climbed_job_ids_appropriately
    assert_equal Float::INFINITY, @connection.min_climbed_job_id
    assert_equal 0, @connection.max_climbed_job_id

    max_id = @connection.max_job_id
    @connection.expects(:max_job_id).once.returns(max_id)
    @connection.each {}

    assert_equal 1, @connection.min_climbed_job_id
    assert_equal max_id, @connection.max_climbed_job_id
  end


  def test_test_tube_is_initialized_but_configurable
    assert_equal StalkClimber::Connection::DEFAULT_TUBE, @connection.test_tube
    tube_name = 'test_tube'
    @connection.test_tube = tube_name
    assert_equal tube_name, @connection.test_tube
  end


  def test_with_job_yields_nil_or_the_requested_job_if_it_exists
    assert_nothing_raised do
      @connection.with_job(@connection.max_job_id) do |job|
        assert_equal nil, job
      end
    end
    probe = @connection.transmit(StalkClimber::Connection::PROBE_TRANSMISSION)
    @connection.with_job(probe[:id]) do |job|
      assert_equal probe[:id], job[:id]
    end

    @connection.transmit("delete #{probe[:id]}")
  end


  def test_with_job_bang_does_not_execute_block_and_raises_error_if_job_does_not_exist
    assert_raise Beaneater::NotFoundError do
      @connection.with_job!(@connection.max_job_id) do |job|
        raise 'StalkClimber::Connnection#with_job! should not execute block for nonexistent job'
      end
    end
  end

end