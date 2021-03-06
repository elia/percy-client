RSpec.describe Percy::Client::Environment do
  def clear_env_vars
    # Unset Percy vars.
    ENV['PERCY_COMMIT'] = nil
    ENV['PERCY_BRANCH'] = nil
    ENV['PERCY_PULL_REQUEST'] = nil
    ENV['PERCY_REPO_SLUG'] = nil

    # Unset Travis vars.
    ENV['TRAVIS_BUILD_ID'] = nil
    ENV['TRAVIS_COMMIT'] = nil
    ENV['TRAVIS_BRANCH'] = nil
    ENV['TRAVIS_PULL_REQUEST'] = nil
    ENV['TRAVIS_REPO_SLUG'] = nil

    # Unset Jenkins vars.
    ENV['JENKINS_URL'] = nil
    ENV['ghprbPullId'] = nil
    ENV['ghprbActualCommit'] = nil
    ENV['ghprbTargetBranch'] = nil

    # Unset Circle CI vars.
    ENV['CIRCLECI'] = nil
    ENV['CIRCLE_SHA1'] = nil
    ENV['CIRCLE_BRANCH'] = nil
    ENV['CIRCLE_PROJECT_USERNAME'] = nil
    ENV['CIRCLE_PROJECT_REPONAME'] = nil
    ENV['CI_PULL_REQUESTS'] = nil

    # Unset Codeship vars.
    ENV['CI_NAME'] = nil
    ENV['CI_BRANCH'] = nil
    ENV['CI_PULL_REQUEST'] = nil
    ENV['CI_COMMIT_ID'] = nil
  end

  before(:each) do
    @original_env = {
      'TRAVIS_BUILD_ID' => ENV['TRAVIS_BUILD_ID'],
      'TRAVIS_COMMIT' => ENV['TRAVIS_COMMIT'],
      'TRAVIS_BRANCH' => ENV['TRAVIS_BRANCH'],
      'TRAVIS_PULL_REQUEST' => ENV['TRAVIS_PULL_REQUEST'],
      'TRAVIS_REPO_SLUG' => ENV['TRAVIS_REPO_SLUG'],
    }
    clear_env_vars
  end
  after(:each) do
    clear_env_vars
    ENV['TRAVIS_BUILD_ID'] = @original_env['TRAVIS_BUILD_ID']
    ENV['TRAVIS_COMMIT'] = @original_env['TRAVIS_COMMIT']
    ENV['TRAVIS_BRANCH'] = @original_env['TRAVIS_BRANCH']
    ENV['TRAVIS_PULL_REQUEST'] = @original_env['TRAVIS_PULL_REQUEST']
    ENV['TRAVIS_REPO_SLUG'] = @original_env['TRAVIS_REPO_SLUG']
  end

  context 'no known CI environment' do
    describe '#current_ci' do
      it 'is nil' do
        expect(Percy::Client::Environment.current_ci).to be_nil
      end
    end
    describe '#branch' do
      it 'returns master if not in a git repo' do
        expect(Percy::Client::Environment).to receive(:_raw_branch_output).and_return('')
        expect(Percy::Client::Environment.branch).to eq('master')
      end
      it 'reads from the current local repo' do
        expect(Percy::Client::Environment.branch).to_not be_empty
      end
      it 'can be overridden with PERCY_BRANCH' do
        ENV['PERCY_BRANCH'] = 'test-branch'
        expect(Percy::Client::Environment.branch).to eq('test-branch')
      end
    end
    describe '#_commit_sha' do
      it 'returns nil if no environment info can be found' do
        expect(Percy::Client::Environment._commit_sha).to be_nil
      end
      it 'can be overridden with PERCY_COMMIT' do
        ENV['PERCY_COMMIT'] = 'test-commit'
        expect(Percy::Client::Environment._commit_sha).to eq('test-commit')
      end
    end
    describe '#pull_request_number' do
      it 'returns nil if no CI environment' do
        expect(Percy::Client::Environment.pull_request_number).to be_nil
      end
      it 'can be overridden with PERCY_PULL_REQUEST' do
        ENV['PERCY_PULL_REQUEST'] = '123'
        ENV['TRAVIS_BUILD_ID'] = '1234'
        ENV['TRAVIS_PULL_REQUEST'] = '256'
        expect(Percy::Client::Environment.pull_request_number).to eq('123')
      end
    end
    describe '#repo' do
      it 'returns the current local repo name' do
        expect(Percy::Client::Environment.repo).to eq('percy/percy-client')
      end
      it 'can be overridden with PERCY_REPO_SLUG' do
        ENV['PERCY_REPO_SLUG'] = 'percy/slug'
        expect(Percy::Client::Environment.repo).to eq('percy/slug')
      end
      it 'handles git ssh urls' do
        expect(Percy::Client::Environment).to receive(:_get_origin_url)
          .once.and_return('git@github.com:org-name/repo-name.git')
        expect(Percy::Client::Environment.repo).to eq('org-name/repo-name')

        expect(Percy::Client::Environment).to receive(:_get_origin_url)
          .once.and_return('git@github.com:org-name/repo-name.org.git')
        expect(Percy::Client::Environment.repo).to eq('org-name/repo-name.org')

        expect(Percy::Client::Environment).to receive(:_get_origin_url)
          .once.and_return('git@custom-local-hostname:org-name/repo-name.org')
        expect(Percy::Client::Environment.repo).to eq('org-name/repo-name.org')
      end
      it 'handles git https urls' do
        expect(Percy::Client::Environment).to receive(:_get_origin_url)
          .once.and_return('https://github.com/org-name/repo-name.git')
        expect(Percy::Client::Environment.repo).to eq('org-name/repo-name')

        expect(Percy::Client::Environment).to receive(:_get_origin_url)
          .once.and_return('https://github.com/org-name/repo-name.org.git')
        expect(Percy::Client::Environment.repo).to eq('org-name/repo-name.org')

        expect(Percy::Client::Environment).to receive(:_get_origin_url)
          .once.and_return("https://github.com/org-name/repo-name.org\n")
        expect(Percy::Client::Environment.repo).to eq('org-name/repo-name.org')
      end
      it 'errors if unable to parse local repo name' do
        expect(Percy::Client::Environment).to receive(:_get_origin_url).once.and_return('foo')
        expect { Percy::Client::Environment.repo }.to raise_error(
          Percy::Client::Environment::RepoNotFoundError)
      end
    end
  end
  context 'in Jenkins CI' do
    before(:each) do
      ENV['JENKINS_URL'] = 'http://localhost:8080/'
      ENV['ghprbPullId'] = '123'
      ENV['ghprbTargetBranch'] = 'jenkins-target-branch'
      ENV['ghprbActualCommit'] = 'jenkins-actual-commit'
    end

    describe '#current_ci' do
      it 'is :jenkins' do
        expect(Percy::Client::Environment.current_ci).to eq(:jenkins)
      end
    end
    describe '#branch' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.branch).to eq('jenkins-target-branch')
      end
    end
    describe '#_commit_sha' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment._commit_sha).to eq('jenkins-actual-commit')
      end
    end
    describe '#pull_request_number' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.pull_request_number).to eq('123')
      end
    end
    describe '#repo' do
      it 'returns the current local repo name' do
        expect(Percy::Client::Environment.repo).to eq('percy/percy-client')
      end
    end
  end
  context 'in Travis CI' do
    before(:each) do
      ENV['TRAVIS_BUILD_ID'] = '1234'
      ENV['TRAVIS_PULL_REQUEST'] = '256'
      ENV['TRAVIS_REPO_SLUG'] = 'travis/repo-slug'
      ENV['TRAVIS_COMMIT'] = 'travis-commit-sha'
      ENV['TRAVIS_BRANCH'] = 'travis-branch'
    end

    describe '#current_ci' do
      it 'is :travis' do
        expect(Percy::Client::Environment.current_ci).to eq(:travis)
      end
    end
    describe '#branch' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.branch).to eq('travis-branch')
      end
    end
    describe '#_commit_sha' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment._commit_sha).to eq('travis-commit-sha')
      end
    end
    describe '#pull_request_number' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.pull_request_number).to eq('256')
      end
    end
    describe '#repo' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.repo).to eq('travis/repo-slug')
      end
    end
  end
  context 'in Circle CI' do
    before(:each) do
      ENV['CIRCLECI'] = 'true'
      ENV['CIRCLE_BRANCH'] = 'circle-branch'
      ENV['CIRCLE_SHA1'] = 'circle-commit-sha'
      ENV['CIRCLE_PROJECT_USERNAME'] = 'circle'
      ENV['CIRCLE_PROJECT_REPONAME'] = 'repo-name'
      ENV['CI_PULL_REQUESTS'] = 'https://github.com/owner/repo-name/pull/123'
    end

    describe '#current_ci' do
      it 'is :circle' do
        expect(Percy::Client::Environment.current_ci).to eq(:circle)
      end
    end
    describe '#branch' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.branch).to eq('circle-branch')
      end
    end
    describe '#_commit_sha' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment._commit_sha).to eq('circle-commit-sha')
      end
    end

    describe '#pull_request_number' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.pull_request_number).to eq('123')
      end
    end
    describe '#repo' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.repo).to eq('circle/repo-name')
      end
    end
  end
  context 'in Codeship' do
    before(:each) do
      ENV['CI_NAME'] = 'codeship'
      ENV['CI_BRANCH'] = 'codeship-branch'
      ENV['CI_PULL_REQUEST'] = 'false'  # This is always false on Codeship, unfortunately.
      ENV['CI_COMMIT_ID'] = 'codeship-commit-sha'
    end

    describe '#current_ci' do
      it 'is :codeship' do
        expect(Percy::Client::Environment.current_ci).to eq(:codeship)
      end
    end
    describe '#branch' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.branch).to eq('codeship-branch')
      end
    end
    describe '#_commit_sha' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment._commit_sha).to eq('codeship-commit-sha')
      end
    end
    describe '#pull_request_number' do
      it 'reads from the CI environment' do
        expect(Percy::Client::Environment.pull_request_number).to be_nil
      end
    end
    describe '#repo' do
      it 'returns the current local repo name' do
        expect(Percy::Client::Environment.repo).to eq('percy/percy-client')
      end
    end
  end
  describe 'local git repo methods' do
    describe '#commit' do
      it 'returns current local commit data' do
        commit = Percy::Client::Environment.commit
        expect(commit[:branch]).to_not be_empty
        expect(commit[:sha]).to_not be_empty
        expect(commit[:sha].length).to eq(40)

        expect(commit[:author_email]).to match(/.+@.+\..+/)
        expect(commit[:author_name]).to_not be_empty
        expect(commit[:committed_at]).to_not be_empty
        expect(commit[:committer_email]).to_not be_empty
        expect(commit[:committer_name]).to_not be_empty
        expect(commit[:message]).to_not be_empty
      end
      it 'returns only branch if commit data cannot be found' do
        expect(Percy::Client::Environment).to receive(:_raw_commit_output).once.and_return(nil)

        commit = Percy::Client::Environment.commit
        expect(commit[:branch]).to be
        expect(commit[:sha]).to be_nil

        expect(commit[:author_email]).to be_nil
        expect(commit[:author_name]).to be_nil
        expect(commit[:committed_at]).to be_nil
        expect(commit[:committer_email]).to be_nil
        expect(commit[:committer_name]).to be_nil
        expect(commit[:message]).to be_nil
      end
    end
  end
end
