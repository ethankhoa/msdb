FactoryGirl.define do
  factory :item do
    upc {until(!Item.select(:upc ).map(&:upc ).include?(i = (1+rand(99999999998)))); end; i}
    description { ["peanut butter",
                   "small red beans",
                   "Del monte Mandarin Oranges",
                   "tartar sauce",
                   "whole grain bread",
                   "eggs",
                   "Ovaltine",
                   "Seneca Mixed vegetables",
                   "CRYSTAL LIGHT",
                   "Pork & Beans"].sample }
    weight_oz 12
    category_id {1+rand(4)}
    count 1
    qoh {rand(10) + 1}

    trait :with_barcode do
      sku nil
      upc {until(!Item.select(:upc ).map(&:upc ).include?(i = (1+rand(99999999998)))); end; i}
    end

    trait :with_known_barcode do
      sku nil
      upc 12341234
    end

    trait :with_sku do
      upc nil
      sku{until(!Item.select(:sku).map(&:sku).include?(i = (1+rand(998)))); end; i}
    end

    factory :item_with_barcode, :traits => [:with_barcode]

    factory :item_with_known_barcode, :traits => [:with_known_barcode]

    factory :item_with_sku, :traits => [:with_sku]
  end
end
