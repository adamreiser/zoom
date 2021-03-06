require "hilighter"
require "scoobydoo"
require "shellwords"

class Zoom::Profile < Hash
    attr_reader :format_flags
    attr_reader :pattern
    attr_reader :taggable

    def after(a = nil)
        self["after"] = a.strip if (a)
        self["after"] ||= ""
        return self["after"]
    end

    def before(b = nil)
        self["before"] = b.strip if (b)
        self["before"] ||= ""
        return self["before"]
    end

    def camel_case_to_underscore(clas)
        # Convert camelcase class to unscore separated string
        name = clas.to_s.split("::")[-1]
        name.gsub!(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
        name.gsub!(/([a-z0-9])([A-Z])/, "\\1_\\2")
        name.tr!("-", "_")
        return name.downcase
    end
    private :camel_case_to_underscore

    def class_name
        return self["class"]
    end

    def exe(header)
        # Emulate grep
        case operator.split("/")[-1]
        when "find"
            cmd = [
                before,
                operator,
                header["paths"],
                flags,
                header["args"],
                header["pattern"],
                after
            ].join(" ").strip
        else
            cmd = [
                before,
                operator,
                @format_flags,
                flags,
                header["args"],
                header["pattern"].shellescape,
                header["paths"],
                after
            ].join(" ").strip
        end
        return %x(#{cmd})
    end

    def flags(f = nil)
        self["flags"] = f.strip if (f)
        self["flags"] ||= ""
        return self["flags"]
    end

    def self.from_json(json)
        begin
            return profile_by_name(json["class"]).new(
                json["name"],
                json["operator"].nil? ? "" : json["operator"],
                json["flags"].nil? ? "" : json["flags"],
                json["before"].nil? ? "" : json["before"],
                json["after"].nil? ? "" : json["after"]
            )
        rescue NoMethodError
            raise Zoom::Error::ProfileNotNamed.new(json)
        rescue NameError
            raise Zoom::Error::ProfileClassUnknown.new(json["class"])
        end
    end

    def go(editor, results)
        Zoom::Editor.new(editor).open(results)
    end

    def hilight_after(str)
        return str if (!Zoom.hilight?)
        return str.yellow
    end
    private :hilight_after

    def hilight_before(str)
        return str if (!Zoom.hilight?)
        return str.yellow
    end
    private :hilight_before

    def hilight_class
        return class_name if (!Zoom.hilight?)
        return class_name.cyan
    end
    private :hilight_class

    def hilight_flags(str)
        return str if (!Zoom.hilight?)
        return str.magenta
    end
    private :hilight_flags

    def hilight_name
        return name if (!Zoom.hilight?)
        return name.white
    end
    private :hilight_name

    def hilight_operator(str)
        return str if (!Zoom.hilight?)
        return str.green
    end
    private :hilight_operator

    def hilight_pattern(str)
        return str if (!Zoom.hilight?)
        return str
    end
    private :hilight_pattern

    def initialize(n = nil, o = nil, f = nil, b = nil, a = nil)
        a ||= ""
        b ||= ""
        f ||= ""
        n ||= camel_case_to_underscore(self.class.to_s)
        o ||= "echo"

        self["class"] = self.class.to_s
        after(a)
        before(b)
        flags(f)
        name(n)
        operator(o)

        @pattern = "" # Setting this will override user input
        @taggable = false
    end

    def name(n = nil)
        self["name"] = n.strip if (n)
        self["name"] ||= ""
        return self["name"]
    end

    def operator(o = nil)
        if (o)
            o.strip!
            op = ScoobyDoo.where_are_you(o)
            raise Zoom::Error::ExecutableNotFound.new(o) if (op.nil?)
            self["operator"] = o
        end
        return self["operator"]
    end

    def preprocess(header)
        # Use hard-coded pattern if defined
        if (
            @pattern &&
            !@pattern.empty? &&
            (header["pattern"] != @pattern)
        )
            header["args"] += " #{header["pattern"]}"
            header["pattern"] = @pattern
        end

        case operator.split("/")[-1]
        when /^ack(-grep)?$/, "ag", "grep", "pt"
            paths = header["paths"].split(" ")
            if (header["pattern"].empty? && !paths.empty?)
                header["pattern"] = paths.delete_at(0)
                header["paths"] = paths.join(" ").strip
                header["paths"] = "." if (header["paths"].empty?)
            end

            # This isn't done here anymore as it'll break hilighting
            # header["pattern"] = header["pattern"].shellescape
        when "find"
            # If additional args are passed, then assume pattern is
            # actually an arg
            if (header["args"] && !header["args"].empty?)
                header["args"] += " #{header["pattern"]}"
                header["pattern"] = ""
            end

            # If pattern was provided then assume it's an iname search
            if (header["pattern"] && !header["pattern"].empty?)
                header["pattern"] = "-iname \"#{header["pattern"]}\""
            end
        end

        # Translate any needed flags
        header["args"] += " #{translate(header["translate"])}"
        header["args"].strip!

        return header
    end

    def self.profile_by_name(clas)
        clas.split("::").inject(Object) do |mod, class_name|
            mod.const_get(class_name)
        end
    end

    def self.subclasses
        ObjectSpace.each_object(Class).select do |clas|
            if (clas < self)
                begin
                    clas.new(clas.to_s)
                    true
                rescue Zoom::Error::ExecutableNotFound
                    false
                end
            else
                false
            end
        end
    end

    def to_s
        ret = Array.new
        ret.push(hilight_name)
        ret.push("#{hilight_class}\n")
        ret.push(hilight_before(before)) if (!before.empty?)
        ret.push(hilight_operator(operator)) if (!operator.empty?)
        ret.push(hilight_flags(flags)) if (!flags.empty?)
        if (@pattern.nil? || @pattern.empty?)
            ret.push(hilight_pattern("PATTERN"))
        else
            ret.push(hilight_pattern("\"#{@pattern}\""))
        end
        ret.push(hilight_after(after)) if (!after.empty?)
        return ret.join(" ").strip
    end

    def translate(from)
        return ""
    end
end
