class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :masqueradable, :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable, :omniauthable

  has_person_name

  validates :first_name, presence: true
end
