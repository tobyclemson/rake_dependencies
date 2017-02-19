require 'spec_helper'

describe RakeDependencies::Tasks::Ensure do
  include_context :rake

  def define_task(name = nil, options = {}, &block)
    ns = options[:namespace] || :dependency
    additional_tasks = options[:additional_tasks] || [:clean, :download, :extract]

    namespace ns do
      additional_tasks.each do |t|
        task t
      end

      subject.new(*(name ? [name] : [])) do |t|
        t.dependency = 'some-dep'
        t.path = 'some/path'
        block.call(t) if block
      end
    end
  end

  context 'task definition' do
    it 'adds an ensure task in the namespace in which it is created' do
      define_task

      expect(Rake::Task['dependency:ensure']).not_to be_nil
    end

    it 'gives the ensure task a description' do
      define_task { |t| t.dependency = 'the-thing' }

      expect(rake.last_description).to(eq('Ensure the-thing present'))
    end

    it 'allows multiple fetch tasks to be declared' do
      define_task(nil, namespace: :dependency1)
      define_task(nil, namespace: :dependency2)

      expect(Rake::Task['dependency1:ensure']).not_to be_nil
      expect(Rake::Task['dependency2:ensure']).not_to be_nil
    end
  end

  context 'parameters' do
    it 'allows the task name to be overridden' do
      define_task(:fetch_if_needed)

      expect(Rake::Task['dependency:fetch_if_needed']).not_to be_nil
    end

    it 'allows the clean task to be overridden' do
      define_task(nil, additional_tasks: [:tidy, :download, :extract]) do |t|
        t.clean_task = :tidy
        t.needs_fetch = lambda { |_| true }
      end

      ensure_task = Rake::Task['dependency:ensure']

      expect(Rake::Task['dependency:tidy']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:download']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:extract']).to(receive(:invoke).ordered)

      ensure_task.invoke
    end

    it 'allows the download task to be overridden' do
      define_task(nil, additional_tasks: [:clean, :dl, :extract]) do |t|
        t.download_task = :dl
        t.needs_fetch = lambda { |_| true }
      end

      ensure_task = Rake::Task['dependency:ensure']

      expect(Rake::Task['dependency:clean']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:dl']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:extract']).to(receive(:invoke).ordered)

      ensure_task.invoke
    end

    it 'allows the extract task to be overridden' do
      define_task(nil, additional_tasks: [:clean, :download, :unarchive]) do |t|
        t.extract_task = :unarchive
        t.needs_fetch = lambda { |_| true }
      end

      ensure_task = Rake::Task['dependency:ensure']

      expect(Rake::Task['dependency:clean']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:download']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:unarchive']).to(receive(:invoke).ordered)

      ensure_task.invoke
    end
  end

  context 'when invoking the fetch required checker' do
    it 'passes the path and default binary directory and version' do
      needs_fetch_checker = double('checker')
      define_task do |t|
        t.path = 'some/path'
        t.needs_fetch = needs_fetch_checker
      end

      expect(needs_fetch_checker)
          .to(receive(:call).with({
              version: nil,
              path: 'some/path',
              binary_directory: 'bin'
          }).and_return(false))

      Rake::Task['dependency:ensure'].invoke
    end

    it 'passes the supplied version' do
      needs_fetch_checker = double('checker')
      define_task do |t|
        t.version = '0.1.0'
        t.path = 'some/path'
        t.needs_fetch = needs_fetch_checker
      end

      expect(needs_fetch_checker)
          .to(receive(:call).with({
              version: '0.1.0',
              path: 'some/path',
              binary_directory: 'bin'
          }).and_return(false))

      Rake::Task['dependency:ensure'].invoke
    end

    it 'passes the supplied binary_directory' do
      needs_fetch_checker = double('checker')
      define_task do |t|
        t.path = 'some/path'
        t.binary_directory = 'exe'
        t.needs_fetch = needs_fetch_checker
      end

      expect(needs_fetch_checker)
          .to(receive(:call).with({
              version: nil,
              path: 'some/path',
              binary_directory: 'exe'
          }).and_return(false))

      Rake::Task['dependency:ensure'].invoke
    end
  end

  context 'when the supplied fetch required checker returns true' do
    it 'invokes clean, download and extract tasks' do
      define_task do |t|
        t.needs_fetch = lambda { |_| true }
      end

      ensure_task = Rake::Task['dependency:ensure']

      expect(Rake::Task['dependency:clean']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:download']).to(receive(:invoke).ordered)
      expect(Rake::Task['dependency:extract']).to(receive(:invoke).ordered)

      ensure_task.invoke
    end
  end

  context 'when the supplied fetch required checker returns false' do
    it 'does nothing' do
      define_task do |t|
        t.needs_fetch = lambda { |_| false }
      end

      ensure_task = Rake::Task['dependency:ensure']

      expect(Rake::Task['dependency:clean']).not_to(receive(:invoke))
      expect(Rake::Task['dependency:download']).not_to(receive(:invoke))
      expect(Rake::Task['dependency:extract']).not_to(receive(:invoke))

      ensure_task.invoke
    end
  end
end