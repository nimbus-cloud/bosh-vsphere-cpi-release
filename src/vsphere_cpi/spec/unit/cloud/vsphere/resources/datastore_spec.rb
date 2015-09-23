require 'spec_helper'

module VSphereCloud
  class Resources
    describe Datastore do
      subject(:datastore) {
        VSphereCloud::Resources::Datastore.new('foo_lun', datastore_mob, 16 * 1024, 8 * 1024)
      }

      let(:datastore_mob) { instance_double('VimSdk::Vim::Datastore', to_s: 'mob_as_string') }

      describe '#mob' do
        it 'returns the mob' do
          expect(datastore.mob).to eq(datastore_mob)
        end
      end

      describe '#name' do
        it 'returns the name' do
          expect(datastore.name).to eq('foo_lun')
        end
      end

      describe '#total_space' do
        it 'returns the total space' do
          expect(datastore.total_space).to eq(16384)
        end
      end

      describe '#synced_free_space' do
        it 'returns the synced free space' do
          expect(datastore.synced_free_space).to eq(8192)
        end
      end

      describe '#allocated_after_sync' do
        it 'returns the allocated after sync' do
          expect(datastore.allocated_after_sync).to eq(0)
        end
      end

      describe '#free_space' do
        it 'returns the free space' do
          expect(datastore.free_space).to eq(8192)
        end
      end

      describe '#allocate' do
        it 'should allocate space' do
          expect { datastore.allocate(1024) }.to change { datastore.free_space }.by(-1024)
        end
      end

      describe '#inspect' do
        it 'returns the printable form' do
          expect(datastore.inspect).to eq("<Datastore: #{datastore_mob} / foo_lun>")
        end
      end

      describe '#debug_info' do
        it 'returns the disk space info' do
          expect(datastore.debug_info).to eq("foo_lun (8192MB free of 16384MB capacity)")
        end
      end

      describe '#to_s' do
        it 'show relevant info' do
          expect(datastore.to_s).to eq("(#{datastore.class.name} (name=\"foo_lun\", mob=\"mob_as_string\"))")
        end
      end
    end
  end
end
