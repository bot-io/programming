package ann;

public class BiasNeuron extends InputNeuron
{
	public BiasNeuron(String name){
		super(name);
		this.input = 1;
	}
}
