class HomeController < ApplicationController
  def index
    @services = [
      {
        name: 'Packages',
        url: 'https://packages.ecosyste.ms',
        description: 'An open API service providing package, version and dependency metadata many open source software ecosystems and registries.',
        icon: 'box-seam',
        repo: 'packages'
      },
      {
        name: 'Digest',
        url: 'https://digest.ecosyste.ms',
        description: 'An open API service providing digests of packages from many open source software ecosystems and registries.',
        icon: 'hash',
        repo: 'digest'
      },
      {
        name: 'Timeline',
        url: 'https://timeline.ecosyste.ms',
        description: 'Browse the timeline of over 4 Billion events for every public repo on GitHub, all the way back to 2015. Data updated hourly from GH Archive.',
        icon: 'clock-history',
        repo: nil #'timeline'
      },
    ]
  end
end