root "."
source "app/**/*.rb", "packs/**/*.rb"
ignore "app/legacy/**/*.rb"
todo "archspec_todo.yml"

architecture :modular_monolith,
  components: {
    billing: "packs/billing/**/*.rb",
    catalog: "packs/catalog/**/*.rb",
    shared: "packs/shared/**/*.rb"
  },
  allow: {
    billing: %i[shared],
    catalog: %i[shared]
  },
  public: {
    billing: "packs/billing/app/public/**/*.rb"
  }

each_directory "engines/*" do |name, path|
  component name, in: "#{path}/**/*.rb"
end

component :controllers, in: "app/controllers/**/*.rb"
component :models, in: "app/models/**/*.rb", except: "app/models/legacy/**/*.rb"
component :services, in: "app/services/**/*.rb"
component :records, descendants_of: "ApplicationRecord"
component :commands, namespace: "Commands"
component :model_concerns, in: "app/models/concerns/**/*.rb"
component :end, in: "app/end/**/*.rb"
component :legacy, constants: %w[OldReport OldExport]

controllers.can_only_use :models, :services, because: "controllers orchestrate, they do not reach into packs"
models.cannot_use :controllers, because: "models must not know about `HTTP`"
models.cannot_reference_constants "ActionController", "ActionView"
models.cannot_call :find_by_sql, receiver: "ActiveRecord::Base"
models.method_names.matching(/\Awith_(?<base>.+)/).requires("without_%{base}")
models.method_names(scope: :class).matching(/\Aget_/).forbidden(except: %i[get_started])
services.cannot_call :render, :redirect_to, :params, :session,
  because: "services do not own the HTTP response"
services.cannot_call :puts, receiver: :none
services.cannot_instantiate_and_invoke
shared.can_only_be_used_by :billing, :catalog, :services
billing.public_api constants: "Billing::Api", namespace: "Billing::Public"
commands.must_implement :call, arity: 1, keywords: :actor
commands.must_implement_one_of :perform, :call, scope: :class
model_concerns.cannot_reference_includers
records.cannot_define :call
self.end.must_be_empty(because: "retired; see `docs/end.md`\nand never use ```fences```")
legacy.method_names.matching(/\Aold_(?<x>.+)/).requires("new_%{x}", on: models, scope: :class)
no_cycles among: %i[controllers models services]
rule ArchSpec::Rules::ForbidDependenciesRule.new(:legacy, [:ghost])

preset :ruby_conventions
