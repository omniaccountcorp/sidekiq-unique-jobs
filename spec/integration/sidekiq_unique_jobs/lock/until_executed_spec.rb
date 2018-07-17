# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SidekiqUniqueJobs::Lock::UntilExecuted, redis: :redis do
  include SidekiqHelpers

  let(:process_one) { described_class.new(item_one, callback) }
  let(:process_two) { described_class.new(item_two, callback) }

  let(:jid_one)      { 'jid one' }
  let(:jid_two)      { 'jid two' }
  let(:worker_class) { UntilExecutedJob }
  let(:unique)       { :until_executed }
  let(:queue)        { :executed }
  let(:args)         { %w[array of arguments] }
  let(:callback)     { -> {} }
  let(:item_one) do
    { 'jid' => jid_one,
      'class' => worker_class.to_s,
      'queue' => queue,
      'unique' => unique,
      'args' => args }
  end
  let(:item_two) do
    { 'jid' => jid_two,
      'class' => worker_class.to_s,
      'queue' => queue,
      'unique' => unique,
      'args' => args }
  end

  describe '#execute' do
    context 'when process one has locked the job' do
      before do
        process_one.lock
      end

      it 'has locked process_one' do
        expect(process_one.locked?).to eq(true)
      end

      it 'prevents process_two from locking' do
        expect(process_two.lock).to eq(nil)
        expect(process_two.locked?).to eq(false)
      end

      context 'when process_one executes the job' do
        context 'and worker raises an error' do
          it 'keeps the lock' do
            expect { process_one.execute { raise 'Hell' } }
              .to raise_error('Hell')

            expect(process_one.locked?).to eq(true)
          end
        end

        it 'prevents process_two from locking' do
          process_one.execute do
            expect(process_two.lock).to eq(nil)
            expect(process_two.locked?).to eq(false)
          end
        end

        it 'prevents process_two from executing' do
          process_one.execute do
            unset = true
            process_two.execute do
              unset = false
            end

            expect(unset).to eq(true)
          end
        end

        it 'keeps being locked while executing' do
          process_one.execute do
            expect(process_one.locked?).to eq(true)
          end
        end

        it 'unlocks process_one after executing' do
          process_one.execute { }
          expect(process_one.locked?).to eq(false)
        end
      end
    end
  end
end
