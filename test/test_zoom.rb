require "minitest/autorun"
require "pathname"
require "zoom"

class RPassTest < Minitest::Test
    def setup
        files = [
            "~/.zoom_cache",
            "~/.zoom_profiles.rb",
            "~/.zoom_shortcuts",
            "~/.zoominfo",
            "~/.zoomrc"
        ]

        files.each do |filename|
            file = Pathname.new(filename).expand_path
            system("mv -f #{file} #{file}.minitest") if (file.exist?)
        end

        Zoom.default
    end

    def teardown
        files = [
            "~/.zoom_cache",
            "~/.zoom_profiles.rb",
            "~/.zoom_shortcuts",
            "~/.zoominfo",
            "~/.zoomrc"
        ]

        files.each do |filename|
            file = Pathname.new("#{filename}.minitest").expand_path
            system("mv -f #{file} #{filename}") if (file.exist?)
        end
    end

    def test_zoom_exceptions
        assert_raises(Zoom::Error::ExecutableNotFoundError) do
            Zoom.instance.configure_editor("asdf")
        end

        assert_raises(Zoom::Error::ProfileAlreadyExistsError) do
            Zoom.instance.add_profile("grep", "GrepProfile")
        end

        assert_raises(Zoom::Error::ProfileCanNotBeModifiedError) do
            Zoom.instance.delete_profile("default")
        end

        assert_raises(Zoom::Error::ProfileCanNotBeModifiedError) do
            Zoom.instance.delete_profile("zoom_find")
        end

        assert_raises(Zoom::Error::ProfileCanNotBeModifiedError) do
            Zoom.instance.rename_profile("asdf", "default")
        end

        assert_raises(Zoom::Error::ProfileCanNotBeModifiedError) do
            Zoom.instance.rename_profile("asdf", "zoom_find")
        end

        assert_raises(Zoom::Error::ProfileClassUnknownError) do
            Zoom.instance.add_profile("asdf", "AsdfProfile")
        end

        assert_raises(Zoom::Error::ProfileDoesNotExistError) do
            Zoom.instance.delete_profile("asdf")
        end
    end
end
