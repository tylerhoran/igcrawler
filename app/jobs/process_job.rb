class ProcessJob < ApplicationJob
  queue_as :default

  def perform
    Post.refresh
    Post.collect_unsponsored
    Post.medias
    User.counts
    User.engage
    User.bucketize
  end

end
