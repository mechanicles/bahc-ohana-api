class AddInterpretationServicesToServices < ActiveRecord::Migration[5.1]
  def change
    add_column :services, :interpretation_services, :text
  end
end
