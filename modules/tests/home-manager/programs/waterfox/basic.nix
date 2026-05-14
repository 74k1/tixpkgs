{ config, ... }:
{
  assertions = [
    {
      assertion = config.programs.waterfox.name == "Waterfox";
      message = "programs.waterfox should expose the Waterfox module defaults.";
    }
    {
      assertion = config.programs.waterfox.configPath == ".waterfox";
      message = "programs.waterfox should use Waterfox's Linux config path.";
    }
  ];
}
