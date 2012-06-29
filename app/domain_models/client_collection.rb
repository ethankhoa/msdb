class ClientCollection
  attr_accessor :clients

  def initialize(clients)
    @clients = clients
  end

  def aggregated_race_demographics
    blank_counts = {:AA => 0, :AS => 0, :WH => 0, :HI => 0, :UNK => 0, :total => clients.count}
    clients.group_by(&:race_or_unknown).inject(blank_counts) do |hash, (r,cc)|
      hash[r.to_sym] = cc.count
      hash
    end
  end

  def counts_by_age_group
    counts = clients.group_by{|c| c.age_group.to_key}
    blank_counts = Client.age_group_base_count
    counts.merge!(blank_counts){|k,v1,v2| v1.length + v2}
    extra_counts = {:children => counts[:infants] + counts[:youths], :seniors => counts[:senior_adults] + counts[:elders]}
    counts.merge!(extra_counts)
  end

  def counts_by_race
    counts = clients.group_by{|c| c.race && c.race.to_sym || :UNK}
    blank_counts = Client.race_base_count
    counts.merge!(blank_counts){|k,v1,v2| v1.length + v2}
    counts.merge!({:total => clients.length})
  end

  def counts_by_age_group_and_gender
    grouped_by_gender.inject({}) do |hash, (g,cc)|
      hash[g] = ClientCollection.new(cc).counts_by_age_group
      hash
    end
  end

  def counts_by_race_and_gender
    grouped_by_gender.inject({}) do |hash, (r,cc)|
      hash[r] = ClientCollection.new(cc).counts_by_race
      hash
    end
  end

  def grouped_by_gender
    empty_groups = {:m => [], :f => [], :unknown => []}
    groups = clients.group_by{|c| c.gender && c.gender.downcase.to_sym || :unknown}
    empty_groups.merge!(groups)
  end

end
