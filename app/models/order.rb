class Order < ActiveRecord::Base
  include AASM

  before_create :generate_token

  belongs_to :user

  has_many :items, class_name: "OrderItem", dependent: :destroy
  has_one :info, class_name: "OrderInfo", dependent: :destroy

  accepts_nested_attributes_for :info

  # create order_items record
  def build_item_cache_from_cart(cart)
    cart.cart_items.each do |cart_item|
      item = items.new
      item.product_name = cart_item.product.title
      item.quantity = cart_item.quantity
      item.price = cart_item.product.price
      item.save
    end

    # cart.items.each do |product|
    #   item = items.new
    #   item.product_name = product.title
    #   item.quantity = 1
    #   item.price = product.price
    #   item.save
    # end
  end

  # fill orders.total
  def calculate_total(cart)
    self.total = cart.total_price
    self.save
  end

  def generate_token
    self.token = SecureRandom.uuid
  end

  def set_payment_with!(method)
    update_columns(payment_method: method)
  end

  def pay!
    update_columns(is_paid: true)
  end

  aasm do
    state :order_placed, initial: true
    state :paid
    state :order_cancelled
    state :shipping
    state :shipped
    state :good_returned

    event :make_payment, after_commit: :pay! do
      transitions from: :order_placed, to: :paid
    end

    event :ship do
      transitions from: :paid, to: :shipping
    end

    event :deliver do
      transitions from: :shipping, to: :shipped
    end

    event :return_good do
      transitions from: :shipped, to: :good_returned
    end

    event :cancel_order do
      transitions from: [:order_placed, :paid], to: :order_cancelled
    end
  end
end
