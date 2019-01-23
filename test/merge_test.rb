require "test_helper"

class MergerTest < Minitest::Test

  def test_merge_subs_current_nil_override
    current = nil
    new_sub = {'rhel' => 'rhel'}
    expected = new_sub.dup
    merged = KatelloAttachSubscription::Utils.merge_subs(current, new_sub, 'override')
    assert_equal expected, merged
  end

  def test_merge_subs_current_nil_keep
    current = nil
    new_sub = {'rhel' => 'rhel'}
    expected = new_sub.dup
    merged = KatelloAttachSubscription::Utils.merge_subs(current, new_sub, 'keep_parsing')
    assert_equal expected, merged
  end

  def test_merge_subs_current_nil_stop
    current = nil
    new_sub = {'rhel' => 'rhel'}
    expected = new_sub.dup
    merged = KatelloAttachSubscription::Utils.merge_subs(current, new_sub, 'stop_parsing')
    assert_equal expected, merged
  end

  def test_merge_subs_current_override
    current = {'something' => 'something'}
    new_sub = {'rhel' => 'rhel'}
    expected = new_sub.dup
    merged = KatelloAttachSubscription::Utils.merge_subs(current, new_sub, 'override')
    assert_equal expected, merged
  end

  def test_merge_subs_current_keep
    current = {'something' => 'something'}
    new_sub = {'rhel' => 'rhel'}
    expected = current.merge(new_sub)
    merged = KatelloAttachSubscription::Utils.merge_subs(current, new_sub, 'keep_parsing')
    assert_equal expected, merged
  end

  def test_merge_subs_current_stop
    current = {'something' => 'something'}
    new_sub = {'rhel' => 'rhel'}
    expected = current.merge(new_sub)
    merged = KatelloAttachSubscription::Utils.merge_subs(current, new_sub, 'stop_parsing')
    assert_equal expected, merged
  end

end
