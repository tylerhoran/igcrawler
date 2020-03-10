class CollectSponsoredJob < ApplicationJob
  queue_as :default

  def perform(*args)
    count = 0
    total = 3061036
    last_node = Post.last.try(:shortcode)
    while count < total
      nodes = RubyInstagramScraper.get_tag_media_nodes("sponsored", last_node)
      break if nodes['edges'].length == 0
      nodes['edges'].map { |e| parse_node(e) }
      last_node = nodes['edges'][-1]['node']['id']
      count += nodes['edges'].length
    end
  end

  private

  def parse_node(e)
    body = e.dig('node', 'edge_media_to_caption', 'edges', 0, 'node', 'text').to_s rescue ""
    body.scan(/#\w+/).flatten.each do |tag|
      Tag.find_or_create_by(name: tag)
    end
    User.find_or_create_by(ig: e.dig('node', 'owner', 'id'))
    # create post
    Post.create(
      body: body,
      shortcode: e.dig('node', 'shortcode'),
      likes: e.dig('node', 'edge_liked_by', 'count'),
      comments: e.dig('node', 'edge_media_to_comment', 'count')
    )
  end
end
