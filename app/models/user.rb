class User < ApplicationRecord
  has_many :posts, dependent: :destroy

  def counts(auth = nil)
    auth ||= User.login
    begin
      user = auth.info_by_name(username)
      raise 'throttled' if user.nil?
      return if user['message'] == 'User not found'
      raise user['message'] if user['status'] == 'fail'
    rescue OpenURI::HTTPError, RuntimeError, JSON::ParserError => e
      puts e
      return if e.to_s.include?('404')

      sleep 60
      retry
    end

    return unless user

    update(followers: user['user']['follower_count'])
  end

  def self.counts
    auth = login
    where(followers: nil).each do |user|
      user.counts(auth)
    end
  end

  def self.login
    account = IgApi::Account.new
    account.login 'tylerhoran9', 'Jexvib-bobfom-1covpe'
  end

  def engage
    posts.where(engagement: nil).each do |post|
      post.update(engagement: (post.likes + post.comments).to_f / followers)
    end
  end

  def self.engage
    includes(:posts).where.not(followers: nil).each(&:engage)
  end

  def self.bucketize
    where(bucket: nil).each do |user|
      case user.followers
      when nil
        next
      when 0..5000
        user.update(bucket: '0-5K')
      when 5_001..10_000
        user.update(bucket: '5K-10k')
      when 10_001..25_000
        user.update(bucket: '10K-25K')
      when 25_001..50_000
        user.update(bucket: '25K-50k')
      when 50_001..75_000
        user.update(bucket: '50K-75k')
      when 75_001..100_000
        user.update(bucket: '75k-100k')
      when 100_001..150_000
        user.update(bucket: '100k-150k')
      when 150_001..250_000
        user.update(bucket: '150k-250k')
      when 250_001..500_000
        user.update(bucket: '250k-500k')
      when 500_001..1_000_000
        user.update(bucket: '500k-1m')
      when 1_000_001..500_000_000
        user.update(bucket: '1m+')
      end
    end
  end
end
