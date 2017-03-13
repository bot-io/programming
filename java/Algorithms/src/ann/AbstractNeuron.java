package ann;
import ann.activation.*;

public class AbstractNeuron {
	public String name = "";
	public double output;
	public double inputSum;
	public IActivationFunction activationFunction = new SigmoidActivationFunction();
	
}
