require "test_helper"

# Test input- and output filter for specific tasks.
# These are task wrap steps added before and after the task.
class VariableMappingTest < Minitest::Spec
  # first task
  Model = ->((options, flow), **o) do
    options["a"]        = options["a"] * 2 # rename to model.a
    options["model.nonsense"] = true       # filter me out

    [Activity::Right, [options, flow]]
  end

  # second task
  Uuid = ->((options, flow), **o) do
    options["a"]             = options["a"] + options["model.a"] # rename to uuid.a
    options["uuid.nonsense"] = false                             # filter me out

    [Activity::Right, [options, flow]]
  end

  let (:activity) do
    Module.new do
      extend Activity::Path()

      task task: Model
      task task: Uuid
    end
  end

  describe "pure Input/Output" do
    it do
        # a => a+1
      model_input  = ->(original_ctx) { new_ctx = Trailblazer.Context({ "a"       => original_ctx["a"]+1 }) } # a = 2   # DISCUSS: how do we access, say. model.class from a container now?
        # a -> model.a
      model_output = ->(original_ctx, new_ctx) {
        _, mutable_data = new_ctx.decompose

        # "strategy" and user block
        original_ctx.merge("model.a" => mutable_data["a"])
      } # return the "total" ctx

        # a => a*3, model.a => model.a
      uuid_input   = ->(original_ctx) { new_ctx = Trailblazer.Context({ "a"       => original_ctx["a"]*3, "model.a" => original_ctx["model.a"] }) }
      uuid_output  = ->(original_ctx, new_ctx) {
        _, mutable_data = new_ctx.decompose

        # "strategy" and user block
        original_ctx.merge({ "uuid.a"  => mutable_data["a"] })
      }

      runtime = {}

      # add filters around Model.
      runtime[ Model ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new( model_input ),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new( model_output ), id: "task_wrap.output", before: "End.success", group: :end
      end

      # add filters around Uuid.
      runtime[ Uuid ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new( uuid_input ),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new( uuid_output ), id: "task_wrap.output", before: "End.success", group: :end
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { "a" => 1 }.freeze,
          {},
        ],

        wrap_runtime: runtime, # dynamic additions from the outside (e.g. tracing), also per task.
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({"a"=>1, "model.a"=>4, "uuid.a" => 7 })
    end
  end

  describe "pure Input/Output xxx" do
    it do
      skip

      model_input  = ->(options) { { "a"       => options["a"]+1 } }
      model_output = ->(options) { { "model.a" => options["a"] } }
      uuid_input   = ->(options) { { "a"       => options["a"]*3, "model.a" => options["model.a"] } }
      uuid_output  = ->(options) { { "uuid.a"  => options["a"] } }

      runtime = {}

      # add filters around Model.
      runtime[ Model ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new( model_input ),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new( model_output ), id: "task_wrap.output", before: "End.success", group: :end
      end

      # add filters around Uuid.
      runtime[ Uuid ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new( uuid_input ),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new( uuid_output ), id: "task_wrap.output", before: "End.success", group: :end
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { "a" => 1 },
          {},
        ],

        wrap_runtime: runtime, # dynamic additions from the outside (e.g. tracing), also per task.
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({"a"=>1, "model.a"=>4, "uuid.a" => 7 })
    end
  end
end


# step Tyrant::Signup, #scope: :auth
#   input do
#     field :email, EmailAddress
#   end
#   output do
#     field :auth, Tyrant::Auth
#   end
