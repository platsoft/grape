

using System.Text;
using System.Web;
using System.Net;
using System.IO;
using System;
using System.Net.Http;
using System.Json;
using System.Collections.Generic;

namespace Grape
{
	class GrapeClient
	{
		string HttpPost (string uri, string parameters)
		{
			HttpWebRequest webRequest = (HttpWebRequest)WebRequest.Create(uri);
			webRequest.ContentType = "application/json";
			webRequest.Accept = "application/json"; 
			webRequest.Method = "POST";
			byte[] bytes = Encoding.ASCII.GetBytes (parameters);
			Stream os = null;
			try
			{
				webRequest.ContentLength = bytes.Length;
				os = webRequest.GetRequestStream();
				os.Write (bytes, 0, bytes.Length);
			}
			catch (WebException ex)
			{
				System.Console.WriteLine("Request error " + ex);
			}
			finally
			{
				if (os != null)
					os.Close();
			}

			try
			{
				WebResponse webResponse = webRequest.GetResponse();
				if (webResponse == null)
					return null;
				StreamReader sr = new StreamReader (webResponse.GetResponseStream());
				return sr.ReadToEnd().Trim();
			}
			catch (WebException ex)
			{
				System.Console.WriteLine("Response error " + ex);
			}
			return null;
		}

		public static void Main()
		{
			KeyValuePair<string, JsonValue>[] vars = new KeyValuePair<string, JsonValue>[]
			{
				new KeyValuePair<string, JsonValue>("username", "HansL"),
				new KeyValuePair<string, JsonValue>("password", "hans")
			};
			JsonObject obj = new JsonObject(vars);
			
			GrapeClient gc = new GrapeClient();

			string ret = gc.HttpPost("http://localhost:3003/grape/login", obj.ToString());
			System.Console.WriteLine(ret);
		}
	}
}




