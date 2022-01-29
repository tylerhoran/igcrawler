class Post < ApplicationRecord
  belongs_to :user, optional: true
  has_and_belongs_to_many :tags
  validates_uniqueness_of :shortcode
  validates_uniqueness_of :ig

  def self.export_sponsored
    post_data = []
    includes(:user, :tags).where(tags: { name: 'sponsored' }).each do |post|
      post_data << {
        user_id: post.user.ig, user_followers: post.user.followers,
        likes: post.likes, comments: post.comments, id: post.ig
      }
    end
    require 'csv'
    CSV.open('public/sponsored_posts.csv', 'w') do |f|
      column_names = post_data.first.keys
      f << column_names
      post_data.each do |post|
        f << post.values
      end
    end
  end

  def self.export_unsponsored
    post_data = []
    tags = Tag.where('name ilike ? ', "%sponsored%").pluck(:id)
    includes(:user, :tags).each do |post|
      next if (post.tags.pluck(:id) & tags).any?

      post_data << {
        user_id: post.user.ig, user_followers: post.user.followers,
        likes: post.likes, comments: post.comments, id: post.ig
      }
    end
    require 'csv'
    CSV.open('public/unsponsored_posts.csv', 'w') do |f|
      column_names = post_data.first.keys
      f << column_names
      post_data.each do |post|
        f << post.values
      end
    end
  end

  def self.collect_unsponsored
    tags = Tag.where.not('name ilike ? ', "%sponsored%")
    two_week_sponsored_count = Post.includes(:tags).where(
      tags: { name: 'sponsored' }
    ).where(posts: { created_at: 2.weeks.ago..Time.current }).count
    total_count = Post.where(created_at: 2.weeks.ago..Time.current).count
    while two_week_sponsored_count.to_f / total_count > 0.5
      begin
        nodes = RubyInstagramScraper.get_tag_media_nodes(tags.sample.name)
      rescue OpenURI::HTTPError => e
        puts e
        next if ['400 Bad Request', '404 Not Found'].include?(e.to_s)

        sleep 60
        retry
      rescue URI::InvalidURIError => e
        puts e
        next
      rescue => e
        next
      end
      process_posts(false, nodes)
      two_week_sponsored_count -= nodes['edges'].length
      total_count = Post.where(created_at: 2.weeks.ago..Time.current).count
    end
  end

  def self.collect(refresh = false)
    active = true
    last = refresh ? nil : Post.last.try(:ig)
    # if refreshing, start with most recent until you hit a post you've already stored
    # if new, start with the last post in the database and work backwards
    while active
      nodes =
        if refresh
          begin
            if last
              RubyInstagramScraper.get_tag_media_nodes('sponsored', last)
              last = nodes['edges'][0].dig('node', 'id')
            else
              RubyInstagramScraper.get_tag_media_nodes('sponsored')
              last = nodes['edges'][0].dig('node', 'id')
            end
          rescue OpenURI::HTTPError
            sleep 60
            retry
          end
        else
          last = Post.last.try(:ig)
          RubyInstagramScraper.get_tag_media_nodes('sponsored')
          if last
            RubyInstagramScraper.get_tag_media_nodes('sponsored', last)
          else
            RubyInstagramScraper.get_tag_media_nodes('sponsored')
          end
        end
      return 'Done' if nodes.empty?

      status = process_posts(true, nodes)
      return 'Done!' if status == false
    end
  end

  def self.refresh
    active = true
    last = nil
    while active
      if last
        begin
          nodes = RubyInstagramScraper.get_tag_media_nodes('sponsored', last)
        rescue OpenURI::HTTPError
          sleep 60
          retry
        end
      else
        begin
          nodes = RubyInstagramScraper.get_tag_media_nodes('sponsored')
        rescue OpenURI::HTTPError
          sleep 60
          retry
        end
      end
      return 'Done!' if nodes['edges'].empty?

      last = nodes['edges'][-1].dig('node', 'id')
      status = process_posts(true, nodes)
      return if status == false
    end
  end

  def self.process_posts(sponsored = true, nodes)
    return false if nodes['edges'].empty?

    return false if nodes['edges'].empty?

    nodes['edges'].each do |node|
      user = User.find_or_create_by(ig: node['node']['owner']['id'])
      return false if Post.find_by(ig: node.dig('node', 'id'))

      post = Post.create(
        shortcode: node.dig('node', 'shortcode'),
        ig: node.dig('node', 'id'),
        user_id: user.id,
        likes: node.dig('node', 'edge_liked_by', 'count'),
        comments: node.dig('node', 'edge_media_to_comment', 'count'),
        sponsored: sponsored
      )
      text = node['node']['edge_media_to_caption']['edges'][0].dig(
        'node', 'text'
      ) rescue nil
      next unless text

      tags = text.scan(/[^\s\#]+/)
      if sponsored
        sponsored = Tag.find_or_create_by(name: 'sponsored')
        post.tags << sponsored
      end
      tags[0...4].each do |tag|
        record = Tag.find_or_create_by(name: tag)
        post.tags << record unless post.tags.include?(record)
      end
    end
  end

  def media
    begin
      post = RubyInstagramScraper.get_media(shortcode)
    rescue OpenURI::HTTPError => e
      user.update(deleted: true) && return if e.to_s.include?('404')

      puts(e) && sleep(60)
      retry
    end
    user.update(
      username: post['owner']['username']
    )
  end

  def self.medias
    Post.includes(:user).where(
      users: { username: nil, deleted: false }
    ).references(:users).each(&:media)
  end

  def self.engagements
    User.where(
      id: includes(:user).where(
        engagement: nil
      ).where.not(users: { followers: nil })
      .pluck(:user_id).uniq
    ).each(&:engage)
  end
end
